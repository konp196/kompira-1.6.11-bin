/*
 * kompira.column_config.js
 *
 *   fork from static/kompira/directory/dir_column_hideable.js
 */
(function(kompira){
    // column-config からカラム種別を取得する
    // 取得できない場合は対応しない
    var columns_type = $('.column-config').data('columns-type');
    if (!columns_type) {
        console.error('columns-type not specified');
        return;
    }
    if (!localStorage) {
        console.warn('localStorage not supported!');
    }

    // 非表示カラムを localStrage から読み込む
    var store_key = 'column_hideable_' + columns_type;
    var hide_columns = load_hide_columns();
    // console.log(store_key, hide_columns);

    // 表示する列を選択するセレクタ
    function column_selector(name) {
        return $("table.column-hideable tr [data-column-name=\"" + name + "\"]");
    };

    // 表示カラム設定の読み込み
    function load_hide_columns(load_defaults) {
        var columns = {};
        if (load_defaults) {
            $(".column-config .column-show-check").each(function(){
                var input = $(this);
                var column_name = input.attr('name');
                var hidden = input.data('hidden');
                columns[column_name] = hidden;
            });
        } else {
            columns = null;
            if (localStorage) {
                columns = JSON.parse(localStorage.getItem(store_key));
            }
            if (!columns) {
                columns = load_hide_columns(true);
            }
        }
        return columns;
    }
    // 表示カラム設定の保存
    function save_hide_columns() {
        if (localStorage) {
            localStorage.setItem(store_key, JSON.stringify(hide_columns));
        }
    }

    // 全てのカラムの表示・非表示状態を更新する
    function update_show_columns() {
        $(".column-config .column-show-check")
        .each(function(){
            var $input = $(this);
            var column_name = $input.attr('name');
            var is_show = !hide_columns[column_name];
            $input.prop('checked', is_show ? 'checked' : false);
            column_selector(column_name).toggle(is_show);
        });
    }

    // カラムの表示切り替え
    function toggle_show_column(e) {
        var $input = $(this);
        var column_name = $input.attr('name');
        var checked = $input.is(':checked');
        column_selector(column_name).toggle(checked);
        hide_columns[column_name] = !checked;
        save_hide_columns();
    }

    // カラム表示列をデフォルトに戻す
    function reset_to_defaults() {
        hide_columns = load_hide_columns(true);
        update_show_columns();
        save_hide_columns();
    }

    // ハンドラ設定
    $(".column-config")
        .on('change', 'input.column-show-check', toggle_show_column)
        .on('click', '.reset', reset_to_defaults)
        .on('click', '.dropdown-menu', function(e){
            // dropdown-menu を自動的に閉じないようにする
            e.stopPropagation();
        });

    // 表示カラム列を更新する
    $(function(){
        update_show_columns();
        $("table.column-hideable").show();
    });

    kompira.column_config = {
        load_hide_columns: load_hide_columns,
        update_show_columns: update_show_columns
    };
})(kompira);
