(function(kompira){
    var XHR;

    //
    // プログレスバーの進捗状況をセット
    //
    function set_progress_bar(val) {
        var $progress_bar = $('div.progress-bar');
        $progress_bar
            .css('width', val + '%')
            .prop('aria-valuenow', val)
    }
    //
    // アップロードキャンセル処理
    //
    function cancel_upload() {
        if (XHR) {
            XHR.abort();
            XHR = null;
            // ボタン連打抑止の解除
            var $submit_btn = $("form.prevent-double-submit button");
            $submit_btn.prop("disabled", false);
        }
    }

    function filter_input(el, index) {
        var $el = $(el);
        var $parent = $($el.parent());
        //
        // CodeMirror でコードが textarea に反映されるようにする
        //
        if ($parent.hasClass('kompira-editor-container')) {
            var code = $parent.data('codemirror').getValue();
            $el.val(code);
        }
        //
        // パスワードフィールド変更/未変更の印付け
        //
        else if ($el.attr('type') == 'password') {
            var $clone = $el.clone();
            var prefix = '';
            if ($el.attr('changed') || !$el.attr('hide-password')) {
                prefix = '!:'
            } else {
                prefix = '=:'
            }
            $clone.val(prefix + $el.val());
            return $clone.get(0);
        }
        return el;
    }

    function ajax_handler() {
        //
        // アップロードファイルがある場合はプログレスバーを表示する
        //
        var has_upload = false;
        var importer = this.importer;

        for (let $input of $('form').find("input[type=file]")) {
            if ($input.value) {
                has_upload = true;
                break;
            }
        }
        XHR = $.ajaxSettings.xhr();
        if (has_upload && XHR.upload) {
            set_progress_bar(0);
            $('#upload-modal').modal('show');
            XHR.upload.addEventListener('progress', function (e) {
                var current = parseInt(e.loaded/e.total*100);
                set_progress_bar(current);
            });
            //
            // アップロード完了したらキャンセル不可にする
            //
            XHR.upload.addEventListener('load', function (e) {
                $('#upload-cancel-btn').prop('disabled', true);
                // メッセージを「インポート中」に変更
                if (importer) {
                    $('#upload-title').text(gettext('Importing...'));
                }
            });
        }
        return XHR;
    }

    function on_success(response, status, xhr) {
        XHR = null;
        $('#upload-modal').modal('hide');
        var location = xhr.getResponseHeader('Location');
        if (xhr.status == 204 && location) {
            window.location.href = location;
        } else {
            var htmlDoc = (new DOMParser()).parseFromString(response, 'text/html');
            var article = htmlDoc.documentElement.getElementsByClassName('article')[0];
            $('section.article').replaceWith(article);
            //
            // 各種初期化関数を呼び出す
            //
            // [TODO] アドホックに追加するのではなく、システマチックに初期化されるようにリファクタする
            //
            $('.django-select2').kompira_djangoSelect2();
            kompira.init_field_array();
            kompira.init_obj_base();
            kompira.init_login_base();
            kompira.uploader();
        }
    }

    function on_error(xhr) {
        XHR = null;
        $('#upload-modal').modal('hide');
        if (xhr.responseText) {
            var htmlDoc = (new DOMParser()).parseFromString(xhr.responseText, 'text/html');
            var body = htmlDoc.documentElement.getElementsByTagName('body')[0];
            if (body) {
                $('body').replaceWith(body);
            }
        }
    }

    kompira.uploader = function(importer) {
        // キャンセルボタン押下時のアップロードキャンセル
        $('#upload-cancel-btn').on('click', cancel_upload);
        // ESCが押されたらアップロードキャンセル
        $(document).keyup(function(e) {
            if (kompira.keybind.keymap[e.keyCode] === 'ESC' && $('#upload-cancel-btn').prop('disabled') == false) {
                cancel_upload();
                $('#upload-modal').modal('hide');
            }
        });
        //
        // AjaxForm によるフォームデータ送信の設定
        //
        $('form.uploader').ajaxForm({
            headers: {
                Accept: "text/html",
            },
            importer: importer,
            xhr: ajax_handler,
            filtering: filter_input,
            success: on_success,
            error: on_error
        });
    }
})(kompira);
