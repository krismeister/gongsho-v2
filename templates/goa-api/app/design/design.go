// Package design holds the API contract. It is app-owned: edit it freely,
// then regenerate with `goa gen` (see README.md). Never edit gen/ by hand.
package design

import . "goa.design/goa/v3/dsl"

var _ = API("example", func() {
	Description("Scaffolded example API. Replace this design with your own services.")
})

var _ = Service("greet", func() {
	Description("Example service. Replace with your own services.")
	Method("hello", func() {
		Description("Greets the given name using the configured greeting word.")
		Payload(String, "Name to greet")
		Result(func() {
			Description("A greeting message.")
			Attribute("greeting", String, "Full greeting text.", func() {
				Example("hello world")
			})
			Required("greeting")
		})
		HTTP(func() {
			GET("/hello/{name}")
		})
	})
})
