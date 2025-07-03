$(function(){
    $(".action-modal").click(function(){
        /**
         * 実行確認ダイアログを表示するリンク
         * <a class="action-modal" ...>
         * 
         * data-action: 実行時に POST する URL
         * data-message: 操作内容を示すメッセージ
         * data-warning: 警告メッセージ (opt)
         */
        var $action_modal = $(this);
        var $action_form = $('#action-form');
        var action = $action_modal.data('action');
        var warning = $action_modal.data('warning');
        var message = $action_form.find(".modal-body .original_message").text();
        // data-message 中に [[keyword]] 表記があれば data-keyword を展開する
        do {
            var replaced = false;
            message = message.replace(/\[\[(\w+)\]\]/g, function(match, keyword) {
                replaced = true;
                return $action_modal.data(keyword);
            });
        } while (replaced)
        $action_form.find('.extra-input').empty();
        $action_form.find(".modal-body .message").toggle(!!message).empty().append(message);
        $action_form.find(".modal-body .warning").toggle(!!warning).find('.warning-text').text(warning);
        $action_form.attr('action', action);
        $('#confirm-dialog').modal();
    });
    //
    // 接続テスト用ダイアログ
    //
    $(".conn-test-modal").click(function(){
        const timeout_margin = 10000;
        var hostname = $(this).data('hostname') || 'localhost';
        var timeout = parseInt($(this).data('timeout')) || 150;  // ブラウザ側では timeout 未設定時は最大 150 秒(+マージン)だけ待つようにする
        var objpath = $(this).data('objpath');
        var header_message = gettext("Testing connection ...");
        var body_message = gettext("Testing connection to [[hostname]] ...");
        set_dialog(header_message, body_message, hostname, gettext('Cancel'));
        $('#conn-test-dialog').modal({'backdrop': 'static'});
        // 接続テスト要求
        $.ajax({
            url: objpath + ".conn_check",
            method: "POST",
            data: {},
            timeout: timeout * 1000 + timeout_margin,
            dataType: "json",
            headers: {
                'X-CSRFToken': UTILS.get_cookie('csrftoken')
            }
        }).done(function(data) {
            // レスポンス受信成功時
            if (data['status'] == 'OK') {
                var header_message = gettext("Connection succeeds");
                var body_message = gettext("Connection to [[hostname]] has been successfully verified.");
                set_dialog(header_message, body_message, hostname, 'OK');
            } else {
                var header_message = gettext("Connection failure");
                var body_message = gettext("Failed to connect to [[hostname]].");
                var reason_message = data['reason'];
                set_dialog(header_message, body_message, hostname, 'OK', reason_message);
            }
        }).fail(function(xhr, status, error) {
            var header_message = gettext("Connection failure");
            var body_message = gettext("Failed to connect to [[hostname]].");
            var reason_message = `Response error: ${error || status}`;
            set_dialog(header_message, body_message, hostname, 'OK', reason_message);
        });
    });
    //
    // 認可フロー開始
    //
    $(".start-auth-flow").click(function(){
        const width=600;
        const height=800;
        var wTop = window.screenTop + (window.innerHeight - height) / 2;
        var wLeft = window.screenLeft + (window.innerWidth - width) / 2;
        var auth_url = $(this).data('authurl');
        var auth_window = window.open(auth_url, 'Authorization Flow', `width=${width},height=${height},top=${wTop},left=${wLeft}`);
        var $auth_dialog = $("#auth-code-dialog");
        //
        // ウィンドウがクローズされたら、メッセージ読み込みのためにリロードする
        //
        const polling_interval = 100;
        var close_check = setInterval(function(){
            if (auth_window.closed) {
                clearInterval(close_check);
                location.reload();
            }
        }, polling_interval);
        //
        // リダイレクトURL入力ダイアログ表示
        //
        $auth_dialog.on("hidden.bs.modal", function(){
            clearInterval(close_check);
            auth_window.close();
        });
        $auth_dialog.find('#id_auth-submit-btn').on('click', function(){
            clearInterval(close_check);
            auth_window.close();
        });
        $auth_dialog.find('#id_redirect_url').val('');
        $auth_dialog.modal({'backdrop': 'static'});
    });
    //
    // 接続ダイアログのメッセージ設定
    //
    function set_dialog(header, body, hostname, button, error_reason) {
        body_message = body.replace(/\[\[hostname\]\]/g, hostname);
        $("#conn-test-dialog .modal-header #header-message").text(header);
        $("#conn-test-dialog .modal-body #body-message").text(body_message);
        $("#conn-test-dialog .modal-footer #button-text").text(button);
        if (error_reason) {
            $("#conn-test-dialog .modal-body #body-reason code").text(error_reason);
            $("#conn-test-dialog .modal-body #body-reason").css("display", "block");
        } else {
            $("#conn-test-dialog .modal-body #body-reason").css("display", "none");
            $("#conn-test-dialog .modal-body #body-reason code").text('');
        }
    }
});