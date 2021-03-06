TEMPLATE_DIR := templates
SASS_DIR := sass
JS_DIR := js
ASSET_DIR := assets
ARCHIVE_DIR := archive
BUILD_DIR := build
NODE_BIN_DIR := ./node_modules/.bin


MUSTACHE_FILES := $(wildcard $(TEMPLATE_DIR)/[!_]*.mustache)
MUSTACHE_PARTIALS := $(wildcard $(TEMPLATE_DIR)/_*.mustache)
YAML_FILES := $(wildcard $(TEMPLATE_DIR)/*.yaml)

# Check for missing Mustache/YAML files
MUSTACHE_BASENAMES := $(basename $(MUSTACHE_FILES))
YAML_BASENAMES := $(basename $(YAML_FILES))
TEMPLATE_PAIRS := $(filter $(YAML_BASENAMES), $(MUSTACHE_BASENAMES))
SINGLE_FILES := $(strip $(addsuffix .yaml,$(filter-out $(TEMPLATE_PAIRS),$(YAML_BASENAMES))) \
                        $(addsuffix .mustache,$(filter-out $(TEMPLATE_PAIRS),$(MUSTACHE_BASENAMES))))

$(if $(SINGLE_FILES),$(error Some Mustache/YAML files are missing. "$(SINGLE_FILES)" cannot be built),)
$(if $(wildcard $(TEMPLATE_DIR)/index.mustache),, \
     $(error $(TEMPLATE_DIR)/index.mustache and $(TEMPLATE_DIR)/index.yaml are missing))

# Place HTML files in their own directory for clean URLs (except for the root
# index.html). For example, "about.mustache" will be built as
# "/about/index.html" instead of "/about.html".
HTML_BUILD := $(foreach slug,$(filter-out index,$(notdir $(MUSTACHE_BASENAMES))),\
                             $(BUILD_DIR)/$(slug)/index.html)
HTML_BUILD += $(BUILD_DIR)/index.html


JS_FILES := $(wildcard $(JS_DIR)/*.js)
JS_BUILD := $(BUILD_DIR)/script.js

SASS_FILE := $(SASS_DIR)/main.scss
SASS_PARTIALS := $(wildcard $(SASS_DIR)/*/_*.scss)
CSS_BUILD := $(BUILD_DIR)/style.css

ASSET_LINKS := $(patsubst $(ASSET_DIR)/%,$(BUILD_DIR)/%,$(wildcard $(ASSET_DIR)/*))
ARCHIVE_LINKS := $(BUILD_DIR)/2016 $(BUILD_DIR)/2017


PROGRAM_DEPS := npm
MISSING_DEPS := $(strip $(foreach dep,$(PROGRAM_DEPS),\
                            $(if $(shell command -v $(dep) 2> /dev/null),,$(dep))))


site: deps $(BUILD_DIR) 2018-soon $(ARCHIVE_LINKS)
2018-soon: $(HTML_BUILD) $(CSS_BUILD) $(JS_BUILD) $(ASSET_LINKS)

$(BUILD_DIR):
	mkdir $@

# MUSTACHE_PARTIALS are added as a prerequisite so that non-partials are rebuilt
# when partials are modified.
# Partials' filenames must have just one dot and one underscore to match the regex.
%.html: %.mustache %.yaml $(MUSTACHE_PARTIALS)
	node -e " \
	    var fs = require('fs'), partials = {}; \
	    '$(MUSTACHE_PARTIALS)'.split(' ').forEach(function(p) { \
	        partials[p.match(/_[^./]+/)[0]] = fs.readFileSync(p, 'utf8'); }); \
	    fs.writeFileSync('$@', require('mustache').render( \
	        fs.readFileSync('$<', 'utf8'), \
	        require('js-yaml').safeLoad(fs.readFileSync('$*.yaml')), \
	        partials));"

	$(NODE_BIN_DIR)/html-beautify -f $@ -r


$(BUILD_DIR)/%.html: $(TEMPLATE_DIR)/%.html
	mv $^ $@

$(BUILD_DIR)/%/index.html: $(TEMPLATE_DIR)/%.html
	mkdir -p $(BUILD_DIR)/$*
	mv $^ $@

# The prerequesite SASS_PARTIALS ensures that CSS_BUILD is rebuilt when
# partials are modified.
$(CSS_BUILD): $(SASS_FILE) $(SASS_PARTIALS)
	$(NODE_BIN_DIR)/node-sass --output-style compressed $< > $@
	$(NODE_BIN_DIR)/postcss --use autoprefixer $@ -o $@

$(JS_BUILD): $(JS_FILES)
	cat $(JS_FILES) > $(JS_BUILD)

$(ASSET_LINKS):
	ln -s ../$(ASSET_DIR)/$(@F) $(BUILD_DIR)

$(ARCHIVE_LINKS): $(BUILD_DIR)/% :
	ln -s ../$(ARCHIVE_DIR)/$* $(BUILD_DIR)


clean:
	rm -rf $(BUILD_DIR)

prod: site
	$(if $(REPO),,$(error Usage: make prod REPO=[directory]))
	$(if $(findstring true,$(shell cd $(REPO) && git rev-parse --is-inside-work-tree 2> /dev/null)),,\
	     $(error $(REPO) is not the work tree of a Git repository, will not copy files))
	$(if $(shell cd $(REPO) && git status --porcelain), \
	     $(error $(REPO) is not clean, commit or stash changes before copying files),)
	find -L $(BUILD_DIR) -maxdepth 1 -type l -exec rm {} +
	rsync -CavhL --del --exclude README.md --exclude LICENSE --exclude CNAME $(BUILD_DIR)/ $(REPO)

watch: site
	@echo "Listening for changes..."
	@$(NODE_BIN_DIR)/chokidar "$(TEMPLATE_DIR)/*.mustache" "$(TEMPLATE_DIR)/*.yaml" \
	    "$(SASS_DIR)" "$(JS_DIR)" "$(ASSET_DIR)" "$(LIVE_DIR)" \
        --silent -c "echo; date +'%-l:%M:%S%P'; make --no-print-directory"

help:
	@echo 'The Los Altos Hacks website'
	@echo
	@echo 'Usage: make [target...]'
	@echo
	@echo 'Available targets:'
	@echo '    site                         Build the whole site (default target)'
	@echo '    clean                        Delete build files'
	@echo '    watch                        Rebuild the site when files change'
	@echo '    prod REPO=[directory]        Build site and copy to production repository'
	@echo '    help                         Show this help dialog'

deps:
	$(if $(MISSING_DEPS),$(error Dependencies missing: $(MISSING_DEPS)),)

	$(if $(findstring MISSING,$(shell npm outdated)), \
	    $(info Some Node packages are missing. Running npm install...) \
	    npm install,)

.PHONY: site 2018-soon clean prod watch help deps

# Disable implicit rules to speed up processing and declutter debug output
.SUFFIXES:
%: %,v
%: RCS/%,v
%: RCS/%
%: s.%
%: SCCS/s.%
