/*
 * キーバインド制御
 */
(function(kompira){
    var Keybind = function(element) {
        this.$element = $(element);
        this.keybinds = {};
    };
    Keybind.prototype.on = function(key, func, desc, primary) {
        this.keybinds[key] = {
            key: key,
            func: func,
            desc: desc,
            primary: primary || 0
        };
        return this;
    };
    Keybind.prototype.off = function(key) {
        delete this.keybinds[key];
        return this;
    };
    Keybind.prototype.get_keybind_from_event = function(e) {
        var key;
        if (e.type == 'keydown') {
            key = this.keymap[e.keyCode];
            if (!key) {
                return null;
            }
            if (e.ctrlKey || e.metaKey) {
                key = "Ctrl-" + key;
            }
        } else {
            key = String.fromCharCode(e.which);
        }
        return this.keybinds[key];
    }
    Keybind.prototype.get_keytexts = function() {
        var descs = [];
        var keybinds = [];
        var keytexts = [];
        for (var key in this.keybinds) {
            keybinds.push(this.keybinds[key]);
        }
        // キーバインドを、優先度，キー文字の順にソートする
        keybinds.sort(function(a, b){
            var cmp = a.primary - b.primary;
            if (cmp == 0) {
                if (a.key < b.key) {
                    cmp = -1;
                } else if (a.key > b.key) {
                    cmp = 1;
                }
            }
            return cmp;
        });
        for (var i=0; i<keybinds.length ; i++) {
            var keydesc = keybinds[i].desc;
            if (!keydesc) {
                continue;
            }
            var keytext = keybinds[i].key;
            if (keytext == ' ') {
                keytext = "Space";
            }
            keytexts.push({keytext: keytext, keydesc: keydesc, func: keybinds[i].func});
        }
        return keytexts;
    };
    Keybind.prototype.show_help = function() {
        var keytexts = this.get_keytexts();
        var descs = [];
        for (var i=0; i<keytexts.length ; i++) {
            var kt = keytexts[i];
            var desc = $('<div>').addClass('row');
            desc.append($('<div>').addClass('col-4 keybind').append($('<span>').text(kt.keytext)));
            desc.append($('<div>').addClass('col-8 keydesc').text(kt.keydesc));
            descs.push(desc);
        }
        this.$element.find('.help-keybind').empty().append(descs);
        this.$element.modal('show');
    };
    Keybind.prototype.keymap = {
        27: 'ESC',
        33: 'PageUp', 34: 'PageDown', 35: 'End', 36: 'Home',
        37: 'Left', 38: 'Up', 39: 'Right', 40: 'Down', 45: 'Insert',
        46: 'Delete',
        112: 'F1', 113: 'F2', 114: 'F3', 115: 'F4',
        116: 'F5', 117: 'F6', 118: 'F7', 119: 'F8',
        120: 'F9', 121: 'F10', 122: 'F11', 123: 'F12',
        219: '[', 221: ']'
    };

    var keybind = new Keybind('#keybind-help');

    /*
     * ページ全体へのキーバインドハンドラ登録
     */
    $(document).on('keydown keypress', function(e){
        if ($(".modal-dialog:visible").length) {
            return true;
        }
        var $target = $(e.target);
        if ($target.is('span.select2-selection, input.select2-search__field, input[type=text], input[type=password], input[type=email], input[type=url], textarea')) {
            return true;
        }
        var kb = keybind.get_keybind_from_event(e);
        if (kb) {
            console.log("kompira.keybind[" + kb.key + "]: " + kb.desc);
            if (kb.func) {
                kb.func(e);
            }
            return false;
        }
        return true;
    });

    /*
     * ESC が押されたら入力をクリアしてフォーカスを解除する
     */
    $('.blur-on-escape').on('keydown', function(e){
        if (kompira.keybind.keymap[e.keyCode] === 'ESC') {
            $(this).val('').blur();
            return false;
        }
        return true;
    });

    /*
     * 標準キーバインドの設定
     */
    keybind.on('?', function(){keybind.show_help()}, gettext('show this message'), 100);
    keybind.on('~', kompira.navigator.go_home, gettext('goto home'), 600);
    keybind.on('^', kompira.navigator.go_parent, gettext('goto parent directory'), 601);

    /*
     * 検索窓へのフォーカス
     */
    var search_query = $('.search-query');
    if (search_query.length) {
        keybind.on('/', function(){search_query.focus().select()}, gettext('search'), 200);
    }

    /*
     * ページネータの前後ページへのジャンプ
     */
    var pagination = $(".pagination");
    if (pagination.length) {
        keybind.on('Ctrl-Right', function(){pagination.find('.page-next').click()}, gettext('goto next page'), 700);
        keybind.on('Ctrl-Left', function(){pagination.find('.page-prev').click()}, gettext('goto prev page'), 700);
    }

    kompira.keybind = keybind;
})(kompira);
