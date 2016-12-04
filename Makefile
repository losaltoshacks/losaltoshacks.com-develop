# Directory definitions
TEMPLATE_DIR := templates
SASS_DIR := sass
JS_DIR := js
ASSET_DIR := assets
WATCH_DIRS := "$(TEMPLATE_DIR)", "$(SASS_DIR)", "$(JS_DIR)", "$(ASSET_DIR)"
ARCHIVE_DIR := archive
BUILD_DIR := build

# File list and build file definitions
HTML_FILES := $(wildcard $(TEMPLATE_DIR)/[!_]*.mustache)
HTML_PARTIALS := $(wildcard $(TEMPLATE_DIR)/_*.mustache)
HTML_BUILD := $(HTML_FILES:.mustache=.html)

# We want to place files such as "about.mustache" in their own directory, so
# that they're built as "/about/index.html" instead of "/about.html". So, we
# run a foreach to rename the files to their appropriate path. But the root
# "index.html" is an exception: it should not be placed in "/index/index.html".
# So we check for its presence and filter it out if necessary.
ifneq (,$(findstring index.html,$(HTML_BUILD)))
# Found index.html, filter it out and add it in at the end
HTML_BUILD := $(filter-out $(TEMPLATE_DIR)/index.html,$(HTML_BUILD))
HTML_BUILD := $(foreach FILE,$(HTML_BUILD),$(BUILD_DIR)/$(notdir $(basename $(FILE)))/index.html)
HTML_BUILD += $(BUILD_DIR)/index.html
else
# Didn't find index.html
HTML_BUILD := $(foreach FILE,$(HTML_BUILD),$(BUILD_DIR)/$(notdir $(basename $(FILE)))/index.html)
endif

JS_FILES := $(wildcard $(JS_DIR)/*.js)
JS_BUILD := $(BUILD_DIR)/script.js

SASS_FILE := $(SASS_DIR)/style.scss
CSS_BUILD := $(BUILD_DIR)/style.css

# Testing for necessary programs
MUSTACHE := $(shell command -v mustache 2> /dev/null)

ifndef MUSTACHE
$(error Mustache is not available. Make sure it is installed)
endif


site: 2017 2016
2017: $(BUILD_DIR) $(HTML_BUILD) $(CSS_BUILD) $(JS_BUILD) assets

$(BUILD_DIR):
	mkdir $(BUILD_DIR)

# We cd to the templates directory so that Mustache can find partials.
# HTML_PARTIALS added as a hack to rebuild non-partials when partials are updated.
# Partials are filtered or ignored from the actual prerequisites.
$(TEMPLATE_DIR)/%.html: $(TEMPLATE_DIR)/%.yaml $(TEMPLATE_DIR)/%.mustache $(HTML_PARTIALS)
	cd $(TEMPLATE_DIR) && mustache $(notdir $(filter-out $(HTML_PARTIALS),$^)) > $(notdir $@)

$(TEMPLATE_DIR)/%.html: $(TEMPLATE_DIR)/%.mustache $(HTML_PARTIALS)
# We echo nothing to fill in for the lack of a YAML file
	cd $(TEMPLATE_DIR) && echo | mustache - $(notdir $<) > $(notdir $@)

$(BUILD_DIR)/index.html: $(TEMPLATE_DIR)/index.html
# Remove lines with just whitespace, as Mustache indents blank lines in partials
	perl -pi -e 's/^[ \t]+$$//gm' $^
	mv $^ $@

$(BUILD_DIR)/%/index.html: $(TEMPLATE_DIR)/%.html
	perl -pi -e 's/^[ \t]+$$//gm' $^
	mkdir -p $(BUILD_DIR)/$(notdir $(basename $^))
	mv $^ $@

$(CSS_BUILD): $(SASS_FILE)
	sass -t compressed --sourcemap=none $< $@
# The CSS must be slurped to use autoprefixer-rails. It should not be slow if
# the file is small enough.
	ruby -e 'require "autoprefixer-rails"; \
	         css = File.read("$@"); \
	         File.open("$@", "w") { |io| io << AutoprefixerRails.process(css) }'

# Depends on jQuery
$(JS_BUILD): $(JS_FILES)
	printf '$$(document).ready(function(){' > $(JS_BUILD)
	cat $(JS_FILES) >> $(JS_BUILD)
	printf "});" >> $(JS_BUILD)


.PHONY: site 2017 assets 2016 clean prod watch

# These rsync targets are phony because rsync only copies files that have changed anyways

# rsync doesn't delete asset files removed from the source tree here because a)
# they will eventually be deleted by make clean/prod, and b) it means that
# macros aren't necessary to build a command to exclude from deleting all the
# files generated by other targets in build/ (e.g. index.html, a file not in
# assets/ which would be removed by rsync --del)
assets:
	rsync -a $(ASSET_DIR)/ $(BUILD_DIR)

# rsync does delete old files here because there are no files to exclude and
# old files will get cleaned up by make clean/prod
2016:
	rsync -a --del $(ARCHIVE_DIR)/2016 $(BUILD_DIR)/

clean:
	rm -rf $(BUILD_DIR)

prod: site
ifndef DIR
	$(error "Please specify a directory to copy the built files to. Usage: make prod DIR=[directory]")
endif
	rsync -Cavh --del --exclude README.md --exclude LICENSE --exclude CNAME $(BUILD_DIR)/ $(DIR)

watch: site
	@echo "Listening for changes..."
	@ruby -e 'require "listen"; \
	          listener = Listen.to($(WATCH_DIRS), latency: 0.5) { \
	            puts "\n" + Time.now.strftime("%-l:%M:%S%P"); \
	            system("make --no-print-directory") \
	          }; listener.start; at_exit { listener.stop }; sleep'

# Disable implicit rules to speed up processing and declutter debug output
.SUFFIXES:
%: %,v
%: RCS/%,v
%: RCS/%
%: s.%
%: SCCS/s.%
