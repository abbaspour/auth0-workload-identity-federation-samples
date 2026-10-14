.DEFAULT_GOAL := build
.PHONY: help install dev build preview test deploy diagram

help: ## Show available targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

public/sequence.svg: sequence.puml
	plantuml -tsvg -o public sequence.puml

diagram: public/sequence.svg ## Render sequence.puml to public/sequence.svg (needs plantuml and graphviz)

node_modules: package.json
	npm install
	@touch node_modules

install: node_modules ## npm install

dev: node_modules ## Start the dev server on http://localhost:5173
	npm run dev

build: node_modules ## Production build into dist/
	npm run build

preview: node_modules ## Serve the production build locally
	npm run preview

test: node_modules ## Run the unit tests
	npm test

deploy: node_modules ## Build and deploy to the Cloudflare Worker (wrangler.jsonc)
	npm run deploy
