/*!
	Autosize v1.18.9 - 2014-05-27
	Automatically adjust textarea height based on user input.
	(c) 2014 Jack Moore - http://www.jacklmoore.com/autosize
	license: http://www.opensource.org/licenses/mit-license.php
*/
(function ($) {
    'use strict';
	var	defaults = {
		className: 'autosizejs',
		id: 'autosizejs',
		append: '\n',
		callback: false,
		resizeDelay: 10,
		placeholder: true
	},

	// border:0 is unnecessary, but avoids a bug in Firefox on OSX
	copy = '<textarea tabindex="-1" style="position:absolute; top:-999px; left:0; right:auto; bottom:auto; border:0; padding: 0; -moz-box-sizing:content-box; -webkit-box-sizing:content-box; box-sizing:content-box; word-wrap:break-word; height:0 !important; min-height:0 !important; overflow:hidden; transition:none; -webkit-transition:none; -moz-transition:none;"/>',

	// line-height is conditionally included because IE7/IE8/old Opera do not return the correct value.
	typographyStyles = [
		'fontFamily',
		'fontSize',
		'fontWeight',
		'fontStyle',
		'letterSpacing',
		'textTransform',
		'wordSpacing',
		'textIndent'
	],

	// to keep track which textarea is being mirrored when adjust() is called.
	mirrored,

	// the mirror element, which is used to calculate what size the mirrored element should be.
	mirror = $(copy).data('autosize', true)[0];

	// test that line-height can be accurately copied.
	mirror.style.lineHeight = '99px';
	if ($(mirror).css('lineHeight') === '99px') {
		typographyStyles.push('lineHeight');
	}
	mirror.style.lineHeight = '';

	$.fn.autosize = function (options) {
		if (!this.length) {
			return this;
		}

		options = $.extend({}, defaults, options || {});

		if (mirror.parentNode !== document.body) {
			$(document.body).append(mirror);
		}

		return this.each(function () {
			var
			ta = this,
			$ta = $(ta),
			maxHeight,
			minHeight,
			boxOffset = 0,
			callback = $.isFunction(options.callback),
			originalStyles = {
				height: ta.style.height,
				overflow: ta.style.overflow,
				overflowY: ta.style.overflowY,
				wordWrap: ta.style.wordWrap,
				resize: ta.style.resize
			},
			timeout,
			width = $ta.width(),
			taResize = $ta.css('resize');

			if ($ta.data('autosize')) {
				// exit if autosize has already been applied, or if the textarea is the mirror element.
				return;
			}
			$ta.data('autosize', true);

			if ($ta.css('box-sizing') === 'border-box' || $ta.css('-moz-box-sizing') === 'border-box' || $ta.css('-webkit-box-sizing') === 'border-box'){
				boxOffset = $ta.outerHeight() - $ta.height();
			}

			// IE8 and lower return 'auto', which parses to NaN, if no min-height is set.
			minHeight = Math.max(parseInt($ta.css('minHeight'), 10) - boxOffset || 0, $ta.height());

			$ta.css({
				overflow: 'hidden',
				overflowY: 'hidden',
				wordWrap: 'break-word' // horizontal overflow is hidden, so break-word is necessary for handling words longer than the textarea width
			});

			if (taResize === 'vertical') {
				$ta.css('resize','none');
			} else if (taResize === 'both') {
				$ta.css('resize', 'horizontal');
			}

			// The mirror width must exactly match the textarea width, so using getBoundingClientRect because it doesn't round the sub-pixel value.
			// window.getComputedStyle, getBoundingClientRect returning a width are unsupported, but also unneeded in IE8 and lower.
			function setWidth() {
				var width;
				var style = window.getComputedStyle ? window.getComputedStyle(ta, null) : false;
				
				if (style) {

					width = ta.getBoundingClientRect().width;

					if (width === 0 || typeof width !== 'number') {
						width = parseInt(style.width,10);
					}

					$.each(['paddingLeft', 'paddingRight', 'borderLeftWidth', 'borderRightWidth'], function(i,val){
						width -= parseInt(style[val],10);
					});
				} else {
					width = $ta.width();
				}

				mirror.style.width = Math.max(width,0) + 'px';
			}

			function initMirror() {
				var styles = {};

				mirrored = ta;
				mirror.className = options.className;
				mirror.id = options.id;
				maxHeight = parseInt($ta.css('maxHeight'), 10);

				// mirror is a duplicate textarea located off-screen that
				// is automatically updated to contain the same text as the
				// original textarea.  mirror always has a height of 0.
				// This gives a cross-browser supported way getting the actual
				// height of the text, through the scrollTop property.
				$.each(typographyStyles, function(i,val){
					styles[val] = $ta.css(val);
				});
				
				$(mirror).css(styles).attr('wrap', $ta.attr('wrap'));

				setWidth();

				// Chrome-specific fix:
				// When the textarea y-overflow is hidden, Chrome doesn't reflow the text to account for the space
				// made available by removing the scrollbar. This workaround triggers the reflow for Chrome.
				if (window.chrome) {
					var width = ta.style.width;
					ta.style.width = '0px';
					var ignore = ta.offsetWidth;
					ta.style.width = width;
				}
			}

			// Using mainly bare JS in this function because it is going
			// to fire very often while typing, and needs to very efficient.
			function adjust() {
				var height, original;

				if (mirrored !== ta) {
					initMirror();
				} else {
					setWidth();
				}

				if (!ta.value && options.placeholder) {
					// If the textarea is empty, copy the placeholder text into 
					// the mirror control and use that for sizing so that we 
					// don't end up with placeholder getting trimmed.
					mirror.value = ($ta.attr("placeholder") || '') + options.append;
				} else {
					mirror.value = ta.value + options.append;
				}

				mirror.style.overflowY = ta.style.overflowY;
				original = parseInt(ta.style.height,10);

				// Setting scrollTop to zero is needed in IE8 and lower for the next step to be accurately applied
				mirror.scrollTop = 0;

				mirror.scrollTop = 9e4;

				// Using scrollTop rather than scrollHeight because scrollHeight is non-standard and includes padding.
				height = mirror.scrollTop;

				if (maxHeight && height > maxHeight) {
					ta.style.overflowY = 'scroll';
					height = maxHeight;
				} else {
					ta.style.overflowY = 'hidden';
					if (height < minHeight) {
						height = minHeight;
					}
				}

				height += boxOffset;

				if (original !== height) {
					ta.style.height = height + 'px';
					if (callback) {
						options.callback.call(ta,ta);
					}
				}
			}

			function resize () {
				clearTimeout(timeout);
				timeout = setTimeout(function(){
					var newWidth = $ta.width();

					if (newWidth !== width) {
						width = newWidth;
						adjust();
					}
				}, parseInt(options.resizeDelay,10));
			}

			if ('onpropertychange' in ta) {
				if ('oninput' in ta) {
					// Detects IE9.  IE9 does not fire onpropertychange or oninput for deletions,
					// so binding to onkeyup to catch most of those occasions.  There is no way that I
					// know of to detect something like 'cut' in IE9.
					$ta.on('input.autosize keyup.autosize', adjust);
				} else {
					// IE7 / IE8
					$ta.on('propertychange.autosize', function(){
						if(event.propertyName === 'value'){
							adjust();
						}
					});
				}
			} else {
				// Modern Browsers
				$ta.on('input.autosize', adjust);
			}

			// Set options.resizeDelay to false if using fixed-width textarea elements.
			// Uses a timeout and width check to reduce the amount of times adjust needs to be called after window resize.

			if (options.resizeDelay !== false) {
				$(window).on('resize.autosize', resize);
			}

			// Event for manual triggering if needed.
			// Should only be needed when the value of the textarea is changed through JavaScript rather than user input.
			$ta.on('autosize.resize', adjust);

			// Event for manual triggering that also forces the styles to update as well.
			// Should only be needed if one of typography styles of the textarea change, and the textarea is already the target of the adjust method.
			$ta.on('autosize.resizeIncludeStyle', function() {
				mirrored = null;
				adjust();
			});

			$ta.on('autosize.destroy', function(){
				mirrored = null;
				clearTimeout(timeout);
				$(window).off('resize', resize);
				$ta
					.off('autosize')
					.off('.autosize')
					.css(originalStyles)
					.removeData('autosize');
			});

			// Call adjust in case the textarea already contains text.
			adjust();
		});
	};
}(window.jQuery || window.$)); // jQuery or jQuery-like library, such as Zepto;
/*
 * BestInPlace (for jQuery)
 * version: 3.0.0.alpha (2014)
 *
 * By Bernat Farrero based on the work of Jan Varwig.
 * Examples at http://bernatfarrero.com
 *
 * Licensed under the MIT:
 * http://www.opensource.org/licenses/mit-license.php
 *
 * @requires jQuery
 *
 * Usage:
 *
 * Attention.
 * The format of the JSON object given to the select inputs is the following:
 * [["key", "value"],["key", "value"]]
 * The format of the JSON object given to the checkbox inputs is the following:
 * ["falseValue", "trueValue"]

 */


function BestInPlaceEditor(e) {
    'use strict';
    this.element = e;
    this.initOptions();
    this.bindForm();
    this.initPlaceHolder();
    jQuery(this.activator).bind('click', {editor: this}, this.clickHandler);
}

BestInPlaceEditor.prototype = {
    // Public Interface Functions //////////////////////////////////////////////

    activate: function () {
        'use strict';
        var to_display;
        if (this.isPlaceHolder()) {
            to_display = "";
        } else if (this.original_content) {
            to_display = this.original_content;
        } else {
            switch (this.formType) {
                case 'input':
                case 'textarea':
                    if (this.display_raw) {
                        to_display = this.element.html().replace(/&amp;/gi, '&');
                    }
                    else {
                        var value = this.element.data('bipValue');
                        if (typeof value === 'undefined') {
                            to_display = '';
                        } else if (typeof value === 'string') {
                            to_display = this.element.data('bipValue').replace(/&amp;/gi, '&');
                        } else {
                            to_display = this.element.data('bipValue');
                        }
                    }
                    break;
                case 'select':
                    to_display = this.element.html();

            }
        }

        this.oldValue = this.isPlaceHolder() ? "" : this.element.html();
        this.display_value = to_display;
        jQuery(this.activator).unbind("click", this.clickHandler);
        this.activateForm();
        this.element.trigger(jQuery.Event("best_in_place:activate"));
    },

    abort: function () {
        'use strict';
        this.activateText(this.oldValue);
        jQuery(this.activator).bind('click', {editor: this}, this.clickHandler);
        this.element.trigger(jQuery.Event("best_in_place:abort"));
        this.element.trigger(jQuery.Event("best_in_place:deactivate"));
    },

    abortIfConfirm: function () {
        'use strict';
        if (!this.useConfirm) {
            this.abort();
            return;
        }

        if (confirm(BestInPlaceEditor.defaults.locales[''].confirmMessage)) {
            this.abort();
        }
    },

    update: function () {
        'use strict';
        var editor = this,
            value = this.getValue();

        // Avoid request if no change is made
        if (this.formType in {"input": 1, "textarea": 1} && value === this.oldValue) {
            this.abort();
            return true;
        }

        editor.ajax({
            "type": BestInPlaceEditor.defaults.ajaxMethod,
            "dataType": BestInPlaceEditor.defaults.ajaxDataType,
            "data": editor.requestData(),
            "success": function (data, status, xhr) {
                editor.loadSuccessCallback(data, status, xhr);
            },
            "error": function (request, error) {
                editor.loadErrorCallback(request, error);
            }
        });


        switch (this.formType) {
            case "select":
                this.previousCollectionValue = value;

                // search for the text for the span
                editor.element.html(this.arrayToObject(this.values)[value]);
                break;

            case "checkbox":
                editor.element.html(this.arrayToObject(this.values)[value]);
                break;

            default:
                if (value !== "") {
                    if (this.display_raw) {
                        editor.element.html(value);
                    } else {
                        editor.element.text(value);
                    }
                } else {
                    editor.element.html(this.placeHolder);
                }
        }

        editor.element.data('bipValue', value);

        editor.element.trigger(jQuery.Event("best_in_place:update"));


    },

    activateForm: function () {
        'use strict';
        alert(BestInPlaceEditor.defaults.locales[''].uninitializedForm);
    },

    activateText: function (value) {
        'use strict';
        this.element.html(value);
        if (this.isPlaceHolder()) {
            this.element.html(this.placeHolder);
        }
    },

    // Helper Functions ////////////////////////////////////////////////////////

    initOptions: function () {
        // Try parent supplied info
        'use strict';
        var self = this;
        self.element.parents().each(function () {
            var $parent = jQuery(this);
            self.url = self.url || $parent.data("bipUrl");
            self.activator = self.activator || $parent.data("bipActivator");
            self.okButton = self.okButton || $parent.data("bipOkButton");
            self.okButtonClass = self.okButtonClass || $parent.data("bipOkButtonClass");
            self.cancelButton = self.cancelButton || $parent.data("bipCancelButton");
            self.cancelButtonClass = self.cancelButtonClass || $parent.data("bipCancelButtonClass");
        });

        // Load own attributes (overrides all others)
        self.url = self.element.data("bipUrl") || self.url || document.location.pathname;
        self.collection = self.element.data("bipCollection") || self.collection;
        self.formType = self.element.data("bipType") || "input";
        self.objectName = self.element.data("bipObject") || self.objectName;
        self.attributeName = self.element.data("bipAttribute") || self.attributeName;
        self.activator = self.element.data("bipActivator") || self.element;
        self.okButton = self.element.data("bipOkButton") || self.okButton;
        self.okButtonClass = self.element.data("bipOkButtonClass") || self.okButtonClass || BestInPlaceEditor.defaults.okButtonClass;
        self.cancelButton = self.element.data("bipCancelButton") || self.cancelButton;
        self.cancelButtonClass = self.element.data("bipCancelButtonClass") || self.cancelButtonClass || BestInPlaceEditor.defaults.cancelButtonClass;
        
        // Fix for default values of 0
        if (self.element.data("bipPlaceholder") == null) {
          self.placeHolder = BestInPlaceEditor.defaults.locales[''].placeHolder;
        } else {
          self.placeHolder = self.element.data("bipPlaceholder");
        }
        
        self.inner_class = self.element.data("bipInnerClass");
        self.html_attrs = self.element.data("bipHtmlAttrs");
        self.original_content = self.element.data("bipOriginalContent") || self.original_content;
        
        // if set the input won't be satinized
        self.display_raw = self.element.data("bip-raw");

        self.useConfirm = self.element.data("bip-confirm");

        if (self.formType === "select" || self.formType === "checkbox") {
            self.values = self.collection;
            self.collectionValue = self.element.data("bipValue") || self.collectionValue;
        }
    },

    bindForm: function () {
        'use strict';
        this.activateForm = BestInPlaceEditor.forms[this.formType].activateForm;
        this.getValue = BestInPlaceEditor.forms[this.formType].getValue;
    },


    initPlaceHolder: function () {
        'use strict';
        // TODO add placeholder for select and checkbox
        if (this.element.html() === "") {
            this.element.html(this.placeHolder);
        }
    },

    isPlaceHolder: function () {
        'use strict';
        // TODO: It only work when form is deactivated.
        // Condition will fail when form is activated
        return this.element.html() === "" || this.element.html() === this.placeHolder;
    },

    getValue: function () {
        'use strict';
        alert(BestInPlaceEditor.defaults.locales[''].uninitializedForm);
    },

    arrayToObject: function(list, values) {
        if (list == null) return {};
        var result = {};
        for (var i = 0, length = list.length; i < length; i++) {
            if (values) {
                result[list[i]] = values[i];
            } else {
                result[list[i][0]] = list[i][1];
            }
        }
        return result;
    },

    // Trim and Strips HTML from text
    sanitizeValue: function (s) {
        'use strict';
        return jQuery.trim(s);
    },

    /* Generate the data sent in the POST request */
    requestData: function () {
        'use strict';
        // To prevent xss attacks, a csrf token must be defined as a meta attribute
        var csrf_token = jQuery('meta[name=csrf-token]').attr('content'),
            csrf_param = jQuery('meta[name=csrf-param]').attr('content');

        var data = "_method=" + BestInPlaceEditor.defaults.ajaxMethod;
        data += "&" + this.objectName + '[' + this.attributeName + ']=' + encodeURIComponent(this.getValue());

        if (csrf_param !== undefined && csrf_token !== undefined) {
            data += "&" + csrf_param + "=" + encodeURIComponent(csrf_token);
        }
        return data;
    },

    ajax: function (options) {
        'use strict';
        options.url = this.url;
        options.beforeSend = function (xhr) {
            xhr.setRequestHeader("Accept", "application/json");
        };
        return jQuery.ajax(options);
    },

    // Handlers ////////////////////////////////////////////////////////////////

    loadSuccessCallback: function (data, status, xhr) {
        'use strict';
        data = jQuery.trim(data);
        //Update original content with current text.
        if (this.display_raw) {
          this.original_content = this.element.html();
        } else {
          this.original_content = this.element.text();
        }

        if (data && data !== "") {
            var response = jQuery.parseJSON(data);
            if (response !== null && response.hasOwnProperty("display_as")) {
                this.element.data('bip-original-content', this.element.text());
                this.element.html(response.display_as);
            }
        }

        this.element.trigger(jQuery.Event("best_in_place:success"), [data, status, xhr]);
        this.element.trigger(jQuery.Event("ajax:success"), [data, status, xhr]);

        // Binding back after being clicked
        jQuery(this.activator).bind('click', {editor: this}, this.clickHandler);
        this.element.trigger(jQuery.Event("best_in_place:deactivate"));

        if (this.collectionValue !== null && this.formType === "select") {
            this.collectionValue = this.previousCollectionValue;
            this.previousCollectionValue = null;
        }
    },

    loadErrorCallback: function (request, error) {
        'use strict';
        this.activateText(this.oldValue);

        this.element.trigger(jQuery.Event("best_in_place:error"), [request, error]);
        this.element.trigger(jQuery.Event("ajax:error"), request, error);

        // Binding back after being clicked
        jQuery(this.activator).bind('click', {editor: this}, this.clickHandler);
        this.element.trigger(jQuery.Event("best_in_place:deactivate"));
    },

    clickHandler: function (event) {
        'use strict';
        event.preventDefault();
        event.data.editor.activate();
    },

    setHtmlAttributes: function () {
        'use strict';
        var formField = this.element.find(this.formType);

        if (this.html_attrs) {
            var attrs = this.html_attrs;
            $.each(attrs, function (key, val) {
                formField.attr(key, val);
            });
        }
    },

    placeButtons: function (output, field) {
        'use strict';
        if (field.okButton) {
            output.append(
                jQuery(document.createElement('input'))
                    .attr('type', 'submit')
                    .attr('class', field.okButtonClass)
                    .attr('value', field.okButton)
            );
        }
        if (field.cancelButton) {
            output.append(
                jQuery(document.createElement('input'))
                    .attr('type', 'button')
                    .attr('class', field.cancelButtonClass)
                    .attr('value', field.cancelButton)
            );
        }
    }
};


// Button cases:
// If no buttons, then blur saves, ESC cancels
// If just Cancel button, then blur saves, ESC or clicking Cancel cancels (careful of blur event!)
// If just OK button, then clicking OK saves (careful of blur event!), ESC or blur cancels
// If both buttons, then clicking OK saves, ESC or clicking Cancel or blur cancels
BestInPlaceEditor.forms = {
    "input": {
        activateForm: function () {
            'use strict';
            var output = jQuery(document.createElement('form'))
                .addClass('form_in_place')
                .attr('action', 'javascript:void(0);')
                .attr('style', 'display:inline');
            var input_elt = jQuery(document.createElement('input'))
                .attr('type', 'text')
                .attr('name', this.attributeName)
                .val(this.display_value);

            // Add class to form input
            if (this.inner_class) {
                input_elt.addClass(this.inner_class);
            }

            output.append(input_elt);
            this.placeButtons(output, this);

            this.element.html(output);
            this.setHtmlAttributes();

            this.element.find("input[type='text']")[0].select();
            this.element.find("form").bind('submit', {editor: this}, BestInPlaceEditor.forms.input.submitHandler);
            if (this.cancelButton) {
                this.element.find("input[type='button']").bind('click', {editor: this}, BestInPlaceEditor.forms.input.cancelButtonHandler);
            }
            if (!this.okButton) {
                this.element.find("input[type='text']").bind('blur', {editor: this}, BestInPlaceEditor.forms.input.inputBlurHandler);
            }
            this.element.find("input[type='text']").bind('keyup', {editor: this}, BestInPlaceEditor.forms.input.keyupHandler);
            this.blurTimer = null;
            this.userClicked = false;
        },

        getValue: function () {
            'use strict';
            return this.sanitizeValue(this.element.find("input").val());
        },

        // When buttons are present, use a timer on the blur event to give precedence to clicks
        inputBlurHandler: function (event) {
            'use strict';
            if (event.data.editor.okButton) {
                event.data.editor.blurTimer = setTimeout(function () {
                    if (!event.data.editor.userClicked) {
                        event.data.editor.abort();
                    }
                }, 500);
            } else {
                if (event.data.editor.cancelButton) {
                    event.data.editor.blurTimer = setTimeout(function () {
                        if (!event.data.editor.userClicked) {
                            event.data.editor.update();
                        }
                    }, 500);
                } else {
                    event.data.editor.update();
                }
            }
        },

        submitHandler: function (event) {
            'use strict';
            event.data.editor.userClicked = true;
            clearTimeout(event.data.editor.blurTimer);
            event.data.editor.update();
        },

        cancelButtonHandler: function (event) {
            'use strict';
            event.data.editor.userClicked = true;
            clearTimeout(event.data.editor.blurTimer);
            event.data.editor.abort();
            event.stopPropagation(); // Without this, click isn't handled
        },

        keyupHandler: function (event) {
            'use strict';
            if (event.keyCode === 27) {
                event.data.editor.abort();
                event.stopImmediatePropagation();
            }
        }
    },

    "select": {
        activateForm: function () {
            'use strict';
            var output = jQuery(document.createElement('form'))
                    .attr('action', 'javascript:void(0)')
                    .attr('style', 'display:inline'),
                selected = '',
                select_elt = jQuery(document.createElement('select'))
                    .attr('class', this.inner_class !== null ? this.inner_class : ''),
                currentCollectionValue = this.collectionValue,
                key, value,
                a = this.arrayToObject(this.values);
            for (key in a) {
                value = a[key];
                var option_elt = jQuery(document.createElement('option'))
                    .val(key)
                    .html(value);
                if (String(key) === String(currentCollectionValue)) option_elt.attr('selected', 'selected');
                select_elt.append(option_elt);
            };
            output.append(select_elt);

            this.element.html(output);
            this.setHtmlAttributes();
            this.element.find("select").bind('change', {editor: this}, BestInPlaceEditor.forms.select.blurHandler);
            this.element.find("select").bind('blur', {editor: this}, BestInPlaceEditor.forms.select.blurHandler);
            this.element.find("select").bind('keyup', {editor: this}, BestInPlaceEditor.forms.select.keyupHandler);
            this.element.find("select")[0].focus();

            // automatically click on the select so you
            // don't have to click twice
            try {
              var e = document.createEvent("MouseEvents");
              e.initMouseEvent("mousedown", true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null);
              this.element.find("select")[0].dispatchEvent(e);
            } 
            catch(e) {
              // browser doesn't support this, e.g. IE8 
            }
        },

        getValue: function () {
            'use strict';
            return this.sanitizeValue(this.element.find("select").val());
        },

        blurHandler: function (event) {
            'use strict';
            event.data.editor.update();
        },

        keyupHandler: function (event) {
            'use strict';
            if (event.keyCode === 27) {
                event.data.editor.abort();
            }
        }
    },

    "checkbox": {
        activateForm: function () {
            'use strict';
            this.collectionValue = !this.getValue();
            this.setHtmlAttributes();
            this.update();
        },

        getValue: function () {
            'use strict';
            return this.collectionValue;
        }
    },

    "textarea": {
        activateForm: function () {
            'use strict';
            // grab width and height of text
            var width = this.element.css('width');
            var height = this.element.css('height');

            // construct form
            var output = jQuery(document.createElement('form'))
                .addClass('form_in_place')
                .attr('action', 'javascript:void(0);')
                .attr('style', 'display:inline');
            var textarea_elt = jQuery(document.createElement('textarea'))
                .attr('name', this.attributeName)
                .val(this.sanitizeValue(this.display_value));

            if (this.inner_class !== null) {
                textarea_elt.addClass(this.inner_class);
            }

            output.append(textarea_elt);

            this.placeButtons(output, this);

            this.element.html(output);
            this.setHtmlAttributes();

            // set width and height of textarea
            jQuery(this.element.find("textarea")[0]).css({'min-width': width, 'min-height': height});
            jQuery(this.element.find("textarea")[0]).autosize();

            this.element.find("textarea")[0].focus();
            this.element.find("form").bind('submit', {editor: this}, BestInPlaceEditor.forms.textarea.submitHandler);

            if (this.cancelButton) {
                this.element.find("input[type='button']").bind('click', {editor: this}, BestInPlaceEditor.forms.textarea.cancelButtonHandler);
            }

            this.element.find("textarea").bind('blur', {editor: this}, BestInPlaceEditor.forms.textarea.blurHandler);
            this.element.find("textarea").bind('keyup', {editor: this}, BestInPlaceEditor.forms.textarea.keyupHandler);
            this.blurTimer = null;
            this.userClicked = false;
        },

        getValue: function () {
            'use strict';
            return this.sanitizeValue(this.element.find("textarea").val());
        },

        // When buttons are present, use a timer on the blur event to give precedence to clicks
        blurHandler: function (event) {
            'use strict';
            if (event.data.editor.okButton) {
                event.data.editor.blurTimer = setTimeout(function () {
                    if (!event.data.editor.userClicked) {
                        event.data.editor.abortIfConfirm();
                    }
                }, 500);
            } else {
                if (event.data.editor.cancelButton) {
                    event.data.editor.blurTimer = setTimeout(function () {
                        if (!event.data.editor.userClicked) {
                            event.data.editor.update();
                        }
                    }, 500);
                } else {
                    event.data.editor.update();
                }
            }
        },

        submitHandler: function (event) {
            'use strict';
            event.data.editor.userClicked = true;
            clearTimeout(event.data.editor.blurTimer);
            event.data.editor.update();
        },

        cancelButtonHandler: function (event) {
            'use strict';
            event.data.editor.userClicked = true;
            clearTimeout(event.data.editor.blurTimer);
            event.data.editor.abortIfConfirm();
            event.stopPropagation(); // Without this, click isn't handled
        },

        keyupHandler: function (event) {
            'use strict';
            if (event.keyCode === 27) {
                event.data.editor.abortIfConfirm();
            }
        }
    }
};

BestInPlaceEditor.defaults = {
    locales: {},
    ajaxMethod: "put",  //TODO Change to patch when support to 3.2 is dropped
    ajaxDataType: 'text',
    okButtonClass: '',
    cancelButtonClass: ''
};

// Default locale
BestInPlaceEditor.defaults.locales[''] = {
    confirmMessage: "Are you sure you want to discard your changes?",
    uninitializedForm: "The form was not properly initialized. getValue is unbound",
    placeHolder: '-'
};

jQuery.fn.best_in_place = function () {
    'use strict';
    function setBestInPlace(element) {
        if (!element.data('bestInPlaceEditor')) {
            element.data('bestInPlaceEditor', new BestInPlaceEditor(element));
            return true;
        }
    }

    jQuery(this.context).delegate(this.selector, 'click', function () {
        var el = jQuery(this);
        if (setBestInPlace(el)) {
            el.click();
        }
    });

    this.each(function () {
        setBestInPlace(jQuery(this));
    });

    return this;
};



