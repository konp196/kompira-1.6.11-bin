var kompira = {};
(function(kompira){
    /* ページナビゲーション関係 */
    kompira.navigator = {
        is_clean: true,
        saved_title: null,

        beforeunload_handler: function() {
            return kompira.config.navigator.unload_confirm;
        },
        setDirty: function() {
            if (!kompira.config.navigator.enabled || !kompira.navigator.is_clean) {
                return;
            }
            kompira.navigator.is_clean = false;
            kompira.navigator.saved_title = document.title;
            document.title = kompira.config.navigator.dirty_title_prefix + kompira.navigator.saved_title;
            $(window).on('beforeunload', kompira.navigator.beforeunload_handler);
        },
        clearDirty: function() {
            if (!kompira.config.navigator.enabled || kompira.navigator.is_clean) {
                return;
            }
            kompira.navigator.is_clean = true;
            document.title = kompira.navigator.saved_title;
            $(window).off('beforeunload', kompira.navigator.beforeunload_handler);
        },
        /*
         * ホームディレクトリへの移動
         */
        go_home: function() {
            window.location = $('.navbar a.navbar-brand').attr('href');
        },
        /*
         * 親ディレクトリへの移動
         */
        go_parent: function() {
            var current = window.location.pathname.replace(/\.\w+$/,'');
            var path = current.split('/');
            path.pop();
            var parent = path.join('/') || '/';
            if (parent != current) {
                parent += '?focus_object=' + current + '&select_objects=' + current;
            }
            window.location = parent;
        }
    };

    /* ソースコード関係 */
    kompira.source = {
        /* ハイライト対象のソース行番号を取得する */
        lineno: function(line) {
            var e = $('#source-lineno');
            if (!e.length) {
                return null;
            } else if (line !== undefined) {
                e.eq(0).text(line);
            }
            var lineno = e.eq(0).text();
            return parseInt(lineno);
        },
        /* 指定した行番号をハイライト表示する */
        highlightLine: function(lineno) {
            if (lineno === undefined) {
                lineno = kompira.source.lineno();
            }
            var cls = kompira.config.source.highlightLine_class;
            var lines = $('#source li');
            lines.removeClass(cls);
            if (lineno != null && lineno > 0) {
                lines.eq(lineno-1).addClass(cls);
            }
        },
        /* 行番号表示幅を設定する */
        marginLeft: function(cols) {
            var linenums = $('.prettyprint ol.linenums');
            if (cols === undefined) {
                var lines = $('li', linenums).length;
                cols = lines.toString().length;
            }
            // 数字一文字の幅を 0.55em として計算する
            var cw = 0.55;
            var margin = (cw * (2 + cols) + 0.4) + 'em';
            linenums.css('margin-left', margin);
            return margin;
        },
        /* ソースコードを prettify する */
        prettify: function(force) {
            if (force) {
                $('.prettyprinted').removeClass('prettyprinted');
            }
            prettyPrint();
            kompira.source.marginLeft();
            kompira.source.highlightLine();
        }
    };

    kompira.config = {
        navigator: {
            enabled: true,
            dirty_title_prefix: '* ',
            unload_confirm: gettext('Data has been changed but not yet saved!')
        },
        source: {
            highlightLine_class: 'highlightLine'
        },
        paginator: {
            pagesize_max: 1000,
            pagesize_default: 20,
            pagesize_list: [10, 20, 50, 100],
            page_kwd: 'page',
            size_kwd: '_size'
        }
    };

    kompira.init_login_base = function(){
        // django-select2/toggle password フィールド の初期化
        kompira.custom_select2_field($('.django-select2'));
        kompira.password_field($('.password-form-container'));
    };

    kompira.init_obj_base = function(){
        // ボタン連打の抑止
        $("form.prevent-double-submit").bind("submit", function() {
            var submit_buttons = $(this).find("button[type='submit']");
            submit_buttons.prop("disabled", true);
        });
        // Firefox/Safari対策
        var submit_buttons = $("form.prevent-double-submit button[type='submit']");
        if (!submit_buttons.data("disabled")) {
            $(window).on("unload", function(){});
            $("form.prevent-double-submit button[type='submit']").prop("disabled", false);
        }
        // オブジェクト表示名の切り替え
        $("th.obj-display-name").click(function () {
            $("span.toggle-name").toggle();
        });
    };

    $(function(){
        // タブを選択（クリック）したら location.replace しておくことで、
        // 別のページ遷移してもこのタブに戻れるようになる
        $('.nav-tabs a[data-toggle="tab"]').on('click', function(){
            window.location.replace(this.href);
        });
        // ハッシュ URI でタブが指定されていれば、クリックして active にする
        var hash = window.location.hash;
        if (hash) {
            $('.nav-tabs a[href="' + hash + '"]').click();
        }
    });
})(kompira);
