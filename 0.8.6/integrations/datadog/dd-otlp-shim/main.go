package main

import (
	"bufio"
	"bytes"
	"compress/gzip"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"
)

type otelAny struct {
	StringValue *string   `json:"stringValue,omitempty"`
	BoolValue   *bool     `json:"boolValue,omitempty"`
	IntValue    *string   `json:"intValue,omitempty"` // OTLP JSON uses strings for 64-bit ints
	DoubleValue *float64  `json:"doubleValue,omitempty"`
	BytesValue  *string   `json:"bytesValue,omitempty"`
	KVListValue *struct{} `json:"kvlistValue,omitempty"`
	ArrayValue  *struct{} `json:"arrayValue,omitempty"`
}

type otelAttr struct {
	Key   string  `json:"key"`
	Value otelAny `json:"value"`
}

type otelLogRecord struct {
	TimeUnixNano         string     `json:"timeUnixNano,omitempty"`
	ObservedTimeUnixNano string     `json:"observedTimeUnixNano,omitempty"`
	SeverityText         string     `json:"severityText,omitempty"`
	Body                 otelAny    `json:"body"`
	Attributes           []otelAttr `json:"attributes,omitempty"`
}

type otelScope struct {
	Name    string `json:"name,omitempty"`
	Version string `json:"version,omitempty"`
}

type otelScopeLogs struct {
	Scope      otelScope       `json:"scope"`
	LogRecords []otelLogRecord `json:"logRecords"`
}

type otelResource struct {
	Attributes []otelAttr `json:"attributes,omitempty"`
}

type otelResourceLogs struct {
	Resource  otelResource    `json:"resource"`
	ScopeLogs []otelScopeLogs `json:"scopeLogs"`
}

type otelEnvelope struct {
	ResourceLogs []otelResourceLogs `json:"resourceLogs"`
}

var (
	flagListen   = flag.String("listen", ":8080", "HTTP listen address")
	flagPath     = flag.String("path", "/dd", "HTTP path to accept Datadog Agent logs")
	flagOtelURL  = flag.String("otlp", "http://gateway-collector.mdai.svc.cluster.local:4318/v1/logs", "OTLP/HTTP /v1/logs endpoint")
	flagAPIKey   = flag.String("require-api-key", "", "If set, require DD-API-KEY header to match")
	flagShimName = flag.String("shim-name", "dd-otlp-shim", "Scope name to embed in OTLP")
	flagEnvTags  = flag.String("default-tags", "", "Optional default tags (comma-separated key:value) to add as attributes")
	httpClient   = &http.Client{Timeout: 10 * time.Second}
)

func main() {
	flag.Parse()

	mux := http.NewServeMux()
	mux.HandleFunc("/dd", handleDD)
	mux.HandleFunc("/api/v2/logs", handleDD) // Datadog Agent HTTP logs path
	mux.HandleFunc("/v1/input", handleDD)    // legacy/alternate
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	s := &http.Server{
		Addr:         *flagListen,
		Handler:      mux,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
	}

	log.Printf("listening on %s, endpoint %s → forwarding to %s", *flagListen, *flagPath, *flagOtelURL)
	if *flagAPIKey != "" {
		log.Printf("DD-API-KEY enforcement ON")
	}
	if err := s.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("server error: %v", err)
	}
}

func handleDD(w http.ResponseWriter, r *http.Request) {
	log.Printf("shim recv %s %s, content-encoding=%s", r.Method, r.URL.Path, r.Header.Get("Content-Encoding"))

	if r.Method != http.MethodPost {
		http.Error(w, "only POST supported", http.StatusMethodNotAllowed)
		return
	}
	if *flagAPIKey != "" && r.Header.Get("DD-API-KEY") != *flagAPIKey {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	bodyReader := io.Reader(r.Body)
	if strings.EqualFold(r.Header.Get("Content-Encoding"), "gzip") {
		gzr, err := gzip.NewReader(r.Body)
		if err != nil {
			http.Error(w, "bad gzip", http.StatusBadRequest)
			return
		}
		defer gzr.Close()
		bodyReader = gzr
	}
	raw, err := io.ReadAll(bodyReader)
	if err != nil {
		http.Error(w, "read error", http.StatusBadRequest)
		return
	}
	events, err := parseDDPayload(raw)
	if err != nil {
		http.Error(w, "invalid DD payload: "+err.Error(), http.StatusBadRequest)
		return
	}

	env := buildOTLPEnvelope(events)
	if err := postOTLP(r.Context(), env); err != nil {
		log.Printf("OTLP post failed: %v", err)
		http.Error(w, "upstream error: "+err.Error(), http.StatusBadGateway)
		return
	}
	w.WriteHeader(http.StatusAccepted)
	_, _ = w.Write([]byte("ok\n"))
}

func parseDDPayload(raw []byte) ([]map[string]any, error) {
	trim := bytes.TrimSpace(raw)
	if len(trim) == 0 {
		return nil, fmt.Errorf("empty body")
	}

	// Try array of JSON objects
	var arr []map[string]any
	if len(trim) > 0 && trim[0] == '[' {
		if err := json.Unmarshal(trim, &arr); err == nil {
			return arr, nil
		}
	}

	// Try single JSON object
	var obj map[string]any
	if len(trim) > 0 && trim[0] == '{' {
		if err := json.Unmarshal(trim, &obj); err == nil {
			return []map[string]any{obj}, nil
		}
	}

	// Fallback: NDJSON
	var out []map[string]any
	sc := bufio.NewScanner(bytes.NewReader(trim))
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		var m map[string]any
		if err := json.Unmarshal([]byte(line), &m); err != nil {
			return nil, fmt.Errorf("bad NDJSON line: %v", err)
		}
		out = append(out, m)
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("unrecognized format")
	}
	return out, nil
}

func buildOTLPEnvelope(events []map[string]any) otelEnvelope {
	now := time.Now()
	nowNano := fmt.Sprintf("%d", now.UnixNano())

	// Resource attributes
	resAttrs := []otelAttr{}
	if len(events) > 0 {
		if service := firstString(events[0], "service"); service != "" {
			resAttrs = append(resAttrs, strAttr("service.name", service))
		}
		if hostname := firstStringOneOf(events[0], "host", "hostname"); hostname != "" {
			resAttrs = append(resAttrs, strAttr("host.name", hostname))
		}
	}
	// Optional default tags from env/flag: key:value,key2:val2
	if *flagEnvTags != "" {
		for _, kv := range strings.Split(*flagEnvTags, ",") {
			kv = strings.TrimSpace(kv)
			if kv == "" {
				continue
			}
			parts := strings.SplitN(kv, ":", 2)
			if len(parts) == 2 {
				resAttrs = append(resAttrs, strAttr(parts[0], parts[1]))
			}
		}
	}

	records := make([]otelLogRecord, 0, len(events))
	for _, ev := range events {
		orig, _ := json.Marshal(ev)
		origStr := string(orig)

		// severity/status if present
		severity := firstStringOneOf(ev, "status", "level", "severity")

		// timestamp heuristic (DD sometimes sends seconds or ms)
		tsNano := nowNano
		if ts := firstNumberOneOf(ev, "timestamp", "ts", "time"); ts != nil {
			// normalize seconds/ms/us/ns to nanoseconds conservatively
			v := *ts
			switch {
			case v > 1e18: // already ns
				tsNano = fmt.Sprintf("%.0f", v)
			case v > 1e15: // µs
				tsNano = fmt.Sprintf("%.0f", v*1e3)
			case v > 1e12: // ms
				tsNano = fmt.Sprintf("%.0f", v*1e6)
			case v > 1e9: // s with fraction
				tsNano = fmt.Sprintf("%.0f", v*1e9)
			default: // seconds
				tsNano = fmt.Sprintf("%.0f", v*1e9)
			}
		}

		recAttrs := []otelAttr{}
		// Preserve some DD-ish fields alongside the raw body
		for _, k := range []string{"ddsource", "source", "service", "host", "hostname", "ddtags", "logger.name"} {
			if s := firstString(ev, k); s != "" {
				recAttrs = append(recAttrs, strAttr("dd."+k, s))
			}
		}

		rec := otelLogRecord{
			TimeUnixNano:         tsNano,
			ObservedTimeUnixNano: nowNano,
			SeverityText:         severity,
			Body:                 otelAny{StringValue: &origStr},
			Attributes:           recAttrs,
		}
		records = append(records, rec)
	}

	return otelEnvelope{
		ResourceLogs: []otelResourceLogs{
			{
				Resource: otelResource{Attributes: resAttrs},
				ScopeLogs: []otelScopeLogs{
					{
						Scope: otelScope{
							Name:    *flagShimName,
							Version: "0.1.1",
						},
						LogRecords: records,
					},
				},
			},
		},
	}
}

func postOTLP(ctx context.Context, env otelEnvelope) error {
	buf, err := json.Marshal(env)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, *flagOtelURL, bytes.NewReader(buf))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode/100 != 2 {
		slurp, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return fmt.Errorf("otlp status %d: %s", resp.StatusCode, strings.TrimSpace(string(slurp)))
	}
	return nil
}

func strAttr(k, v string) otelAttr {
	return otelAttr{
		Key: k,
		Value: otelAny{
			StringValue: &v,
		},
	}
}

func firstString(m map[string]any, key string) string {
	if v, ok := m[key]; ok {
		switch t := v.(type) {
		case string:
			return t
		case fmt.Stringer:
			return t.String()
		case float64:
			return fmt.Sprintf("%.0f", t)
		}
	}
	return ""
}

func firstStringOneOf(m map[string]any, keys ...string) string {
	for _, k := range keys {
		if s := firstString(m, k); s != "" {
			return s
		}
	}
	return ""
}

func firstNumberOneOf(m map[string]any, keys ...string) *float64 {
	for _, k := range keys {
		if v, ok := m[k]; ok {
			switch t := v.(type) {
			case float64:
				return &t
			case json.Number:
				if f, err := t.Float64(); err == nil {
					return &f
				}
			case string:
				if f, err := json.Number(strings.TrimSpace(t)).Float64(); err == nil {
					return &f
				}
			}
		}
	}
	return nil
}
