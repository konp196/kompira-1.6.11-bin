//
// パスワード表示／非表示の切り替え
//
(function(kompira) {
    function _enable_password_button(input) {
        let $passwd_btn = $('button', input.parentNode.parentNode);
        if ($passwd_btn.prop('disabled')) {
            $passwd_btn.prop('disabled', false);
            $(input).val('');
        }
        $(input).attr('changed', true);
    }

    kompira.password_field = function($password, newly) {
        let $passwd_btn = $('button', $password);
        let $passwd_input = $('input', $password);

        // 新規追加時はパスワード入力フィールドを有効化する
        if (newly && $passwd_input[0]) {
            _enable_password_button($passwd_input[0]);
        }

        // パスワードフィールド入力時は変更マークをセットする
        // (changed イベントは必ずしも発火しないため、keydownイベントを捕捉)
        $passwd_input.on('keydown', function(e){
            //
            // パスワードの目玉ボタンが disabled の場合、入力開始とともに有効化する
            // (パスワード自動生成機能による入力の場合 e.key が undefined となる)
            //
            if (!e.key || ["Delete", "Backspace"].includes(e.key) || e.key.length == 1) {
                _enable_password_button(this);
            }
        });
        $passwd_input.one('paste', function(e) {
            // ペーストにより入力された場合もパスワードボタンを有効化
            _enable_password_button(this);
        });
        $passwd_btn.on('keydown mousedown touchstart', function(e){
            if (e.type == 'keydown' && ![' ', 'Enter'].includes(e.key)) {
                return
            }
            let $passwd_input = $('input', this.parentNode.parentNode);
            $passwd_input.attr("type", "text");
        });
        $passwd_btn.on('keyup mouseup touchend', function(e){
            if (e.type == 'keyup' && ![' ', 'Enter'].includes(e.key)) {
                return
            }
            let $passwd_input = $('input', this.parentNode.parentNode);
            $passwd_input.attr("type", "password");
        });
    };
})(kompira);
