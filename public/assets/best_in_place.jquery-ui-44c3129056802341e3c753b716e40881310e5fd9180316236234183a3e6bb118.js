BestInPlaceEditor.forms.date={activateForm:function(){"use strict";var t=this,e=jQuery(document.createElement("form")).addClass("form_in_place").attr("action","javascript:void(0);").attr("style","display:inline"),i=jQuery(document.createElement("input")).attr("type","text").attr("name",this.attributeName).attr("value",this.sanitizeValue(this.display_value));null!==this.inner_class&&i.addClass(this.inner_class),e.append(i),this.element.html(e),this.setHtmlAttributes(),this.element.find("input")[0].select(),this.element.find("form").bind("submit",{editor:this},BestInPlaceEditor.forms.input.submitHandler),this.element.find("input").bind("keyup",{editor:this},BestInPlaceEditor.forms.input.keyupHandler),this.element.find("input").datepicker({onClose:function(){t.update()}}).datepicker("show")},getValue:function(){"use strict";return this.sanitizeValue(this.element.find("input").val())},submitHandler:function(t){"use strict";t.data.editor.update()},keyupHandler:function(t){"use strict";27===t.keyCode&&t.data.editor.abort()}};