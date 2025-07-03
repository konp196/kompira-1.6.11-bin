$(function() {
    var normalize_qual = function(orig, indent, maxlen, force) {
      if (orig === "") {
        return orig
      }
      try {
        var data = JSON.parse(orig);
        if (!(data instanceof Object) || data instanceof Array) {
            throw new Error(gettext("The field qualifier must be a dictionary type!"));
        }
        var text = JSON.stringify(data, null, indent);
        if (maxlen > 0 && text.length > maxlen) {
            throw new Error(gettext("The field qualifier can be JSONized, but it is too long!") + " length=" + text.length);
        }
        return text;
      } catch(e) {
        if (force) {
          return orig;
        } else {
          throw e;
        }
      }
    }
    var indent = 4;
    var maxlength = 1024;
    var options = {
        qualifier: {
            title: gettext("Edit field qualifier"),
            editor_options: {
                codemirror: {
                    mode: "application/json",
                    tabSize: indent,
                },
                disable_commands: ['toggleComment', 'toggleFullscreen'],
            },
            check_delay: 500,
            encode_text: function(text) {
                return normalize_qual(text, 0, maxlength, false);
            },
            decode_text: function(text) {
                return normalize_qual(text, indent, 0, true);
            }
        }
    };
    $("table[id^=dynamic-form-]").on("click", ".popup-editor", function(){
        /* target 要素に設定された mexlength を引き継いでポップアップエディタを開く */
        var $popup_target = $('input:first', this.parentNode.parentNode);
        maxlength = $popup_target.prop('maxlength');
        $("#popup-editor-dialog").popup_editor($popup_target, options.qualifier);
    });
});
