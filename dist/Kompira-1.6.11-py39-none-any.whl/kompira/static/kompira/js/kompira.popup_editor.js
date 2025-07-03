;(function($) {
    $.fn.popup_editor = function($input, options) {
        options = $.extend(true, {}, $.fn.popup_editor.defaults, options);
        var id_textarea = "popup-editor-textarea";
        var encode_text = options.encode_text || function(text){return text};
        var decode_text = options.decode_text || function(text){return text};
        var update_valid = function(valid, mesg) {
            $submit.prop("disabled", !valid);
            $messages.find('.alert').text(mesg).toggle(!valid);
        }
        var clean_text = function() {
            try {
                var cm = kompira.editor.get(id_textarea);
                var text = cm.getValue();
                text = encode_text(text);
                update_valid(true);
                return text;
            } catch(e) {
                update_valid(false, gettext("Invalid field qualifier!") + ": " + e.message);
                throw e;
            }
        }
        var check_timer = undefined;
        var check_validation = function() {
            try {
                clean_text();
            } catch(e) {}
            check_timer = undefined;
        }
        var change_handler = function(cm, change) {
            // check_validation() 呼び出しタイマーを再設定する（遅延させる）
            if (check_timer !== undefined) {
                clearTimeout(check_timer);
            }
            check_timer = setTimeout(check_validation, options.check_delay);
        }
        // ダイアログの生成
        var $modal = $(this);
        var $target = $modal.find('.popup-editor-target');
        var $messages = $modal.find('.popup-editor-messages');
        var $submit = $modal.find('button[type="submit"]');
        $submit.on('click', function(){
            try {
                var text = clean_text();
                $input.val(text);
                $modal.data('changed', true);
                $modal.modal('hide');
            } catch (e) {
                console.warn(e);
            }
            return false;
        });
        $modal.one('shown.bs.modal', function(){
            var text = decode_text($input.val());
            $("#popup-editor-textarea").val(text);
            $('.popup-editor-title', this).text(options.title).toggle(!!options.title);
            var cm = kompira.editor.create(id_textarea, options.editor_options);
            if (options.check_delay > 0) {
                cm.on("change", change_handler);
            }
            check_validation();
        });
        $modal.one('hidden.bs.modal', function(){
            var cm = kompira.editor.get(id_textarea);
            if (cm) {
                cm.off("change", change_handler);
                cm.toTextArea();
            }
            $submit.off('click');
            $input.focus().select();
            if ($modal.data('changed')) {
                $input.trigger('change');
            }
        });
        $modal.data('changed', false);
        $modal.modal('show');
    };
    $.fn.popup_editor.defaults = {
        title: gettext('Popup editor'),
        check_delay: 0,
        editor_options: {
            disable_commands: ['toggleFullscreen'],
            dirty_check: false,
        },
    };
})(jQuery);
