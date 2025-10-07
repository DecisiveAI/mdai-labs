# MDAI cluster Load Balancers

This document describes how to expose OTEL collector's (part of MDAI cluster) receivers endpoints on the AWS EKS cluster. The concepts of how Ingress is managed by the MDAI can be found in [this document](https://docs.mydecisive.ai/advanced/ingress.html?highlight=ingress#managing-ingress-for-the-mdai-clusters-otel-collector)

## Prerequisites

- AWS EKS cluster with the installed [AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)
- DNS names and SSL certificates for gRPC endpoints [details](https://docs.mydecisive.ai/advanced/ingress.html?highlight=ingress#managing-ingress-for-the-mdai-clusters-otel-collector)

## Configuration

1. Add collector gRPC endpoints mapping for host-based load balancers rules [for more details](https://docs.mydecisive.ai/advanced/ingress.html?highlight=ingress#managing-ingress-for-the-mdai-clusters-otel-collector)
```yaml

spec:
  telemetryModule:
    collectors:
      -
        spec:
          ingress:
            type: aws
            collectorEndpoints:
              otlp/1: otlp-1.your.domain.io
              otlp/1: otlp-2.your.domain.io
```
3. Add ingress annotations required by [AWS LB controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/ingress/annotations/) for ALB
```yaml
spec:
  telemetryModule:
    collectors:
      -
        spec:
          ingress:
            annotations:
              alb.ingress.kubernetes.io/certificate-arn: '$SSL_CRT_ARN'
              alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
              alb.ingress.kubernetes.io/load-balancer-name: $ALB_NAME
              alb.ingress.kubernetes.io/backend-protocol-version: GRPC
              alb.ingress.kubernetes.io/scheme: internal
              alb.ingress.kubernetes.io/target-type: ip
              kubernetes.io/ingress.class: alb
            type: aws
            collectorEndpoints:
              otlp/1: otlp-1.your.domain.io
              otlp/1: otlp-2.your.domain.io
```
where
*\$SSL_CRT_ARN* - aws arn for the certificate you are going to use for the ALB endpoint
*\$ALB_NAME* - proposed name for the ALB (gRPC traffic)
4. Add service annotations required by [AWS LB controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/service/annotations/) for NLB
```yaml
spec:
  telemetryModule:
    collectors:
      -
        annotations:
          service.beta.kubernetes.io/aws-load-balancer-name: $NLB_NAME
          service.beta.kubernetes.io/aws-load-balancer-type: external
          service.beta.kubernetes.io/aws-load-balancer-backend-protocol: http
          service.beta.kubernetes.io/aws-load-balancer-scheme: internal
          service.beta.kubernetes.io/aws-load-balancer-ssl-cert: '$SSL_CRT_ARN'
```
where
*\$SSL_CRT_ARN* - aws arn for the certificate you are going to use for the NLB endpoint
*\$NLB_NAME* - proposed name for the NLB (non-gRPC traffic)
## Example configuration
Example configuration can be found [here](./example_ingress_config.yaml)
## Learn more
* Visit our [solutions page](https://www.mydecisive.ai/solutions) for more details MyDecisive's approach to composable observability.
* Head to our [docs](https://docs.mydecisive.ai/) to learn more about MyDecisive's tech.
## Info and Support
* Contact [support@mydecisive.ai](mailto:support@mydecisive.ai) for assistance or to talk to with a member of our support team
* Contact [info@mydecisive.ai](mailto:info@mydecisive.ai) if you're interested in learning more about our solutions