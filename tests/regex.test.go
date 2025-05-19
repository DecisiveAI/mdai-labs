package main

import (
	"fmt"
	"regexp"
)

func credit_card_regex() {
	regex := regexp.MustCompile(`\b(?:\d[ -]*?){0,12}(\d{4})\b`)
	input := "1234-1234-1234-1234"
	template := "****-****-****-$1"
	output := regex.ReplaceAllString(input, template)

	fmt.Println(output)
}

func email_regex() {
	regex := regexp.MustCompile(`\b([a-zA-Z0-9._%+-]{3})[a-zA-Z0-9._%+-]*@([a-zA-Z0-9]{2})[a-zA-Z0-9.-]*\.(\w{2,})\b`)
	input := "sally.jones@example.com"
	template := "$1***@$2**.***"
	output := regex.ReplaceAllString(input, template)

	fmt.Println(output)
}

func phone_regex() {
	regex := regexp.MustCompile(`\b(?:\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?(\d{4})\b`)
	input := "123-456-7890"
	output := regex.ReplaceAllString(input, "***-***-$1")
	fmt.Println(output)
}

func address_regex() {
	regex := regexp.MustCompile(`\b(\d{1,5})\s([\w\s]+),\s([\w\s]+),\s([A-Z]{2})\s(\d{5})\b`)
	input := "1234 Main St, Springfield, IL 62704"
	template := "$1 ******"
	output := regex.ReplaceAllString(input, template)

	fmt.Println(output)
}

func ssn_regex() {
	regex := regexp.MustCompile(`\b\d{3}-\d{2}-(\d{4})\b`)
	input := "123-12-9876"
	template := "***-**-$1"
	output := regex.ReplaceAllString(input, template)

	fmt.Println(output)
}

func name_regex() {
	regex := regexp.MustCompile(`^\p{L}[\p{L}'’\-]*(?: \p{L}[\p{L}'’\-]*)*$`)
	input := "Jean-claude d’souza"
	template := "***REDACTED****"
	output := regex.ReplaceAllString(input, template)

	fmt.Println(output)
}

func main() {
	fmt.Println("begin function")

	// payment
	credit_card_regex()

	// pii
	email_regex()
	phone_regex()
	ssn_regex()
	address_regex()
	name_regex()

	fmt.Println("end function")
}
