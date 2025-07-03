$(function(){
    //
    // テーブルオブジェクト編集時の表示フィールド一覧のUIを提供
    //
    // - オブジェクト型フィールドで選択された型に応じて、表示フィール
    //   ド一覧を作成する。
    // - 表示フィールド一覧は、選択した型のフィールド集合の中から複数
    //   指定することができる。
    //
    //  [NOTE] 本質的には表示フィールド一覧は、選択した型に対象セット
    //         が依存する複数選択可能フィールド（MultipleChoiceField）
    //         なのだが、Kompiraではサポートしていないため、このように
    //         ごちゃごちゃと実装している
    //

    //
    // UI コンポーネント
    //
    var $displayList = $('#dynamic-form-displayList');
    var $typeObject = $('#id_typeObject');
    var $add_btn = $('a.add-row');   // 追加ボタンはKompiraのArrayフィールド標準のもの
    var $field_drop = $('<button class="btn btn-sm btn-outline-secondary dropdown-toggle" data-toggle="dropdown">')
        .append('<i class="fas fa-plus"></i> ', gettext('Add display field'), ' <span class="caret"></span>');
    var $field_list = $('<div class="dropdown-menu">');
    var $field_btn = $('<div id="id_addfield-btn" class="btn-group">')
        .append($field_drop, $field_list);
    var $refresh_btn = $('<button id="id_refresh-btn" class="btn btn-sm btn-outline-secondary" type="button">')
        .html('<i class="fas fa-sync-alt"></i> ' + gettext('Reset to defaults'));
    var $message_box = $('<span>')
        .css({'margin-left': '20px', 'white-space': 'normal'});

    //
    // messge_boxに表示するメッセージ定義
    //
    const msg_refresh_done = gettext('The displayList was reset!');
    const msg_refresh_fail = gettext('Failed to reset the displayList!');

    //
    // Ajax で選択された型オブジェクトのフィールド一覧を取得する
    //
    function fetch_type_fields(type_id) {
        var $deferred = $.Deferred();
        if (!type_id) {
            return $deferred.resolve([]).promise();
        }
        // MEMO: type_id を元にした TypeObject.type_fields API の代替
        $.ajax('/.descendant', {data: {type_object: '/system/types/TypeObject', id: type_id}})
            .done(function(data){
                if (data.results.length == 0) {
                    console.error("fetch_type_fields(type_id="+type_id+"): Type object not found!");
                    $deferred.reject("Type object not found");
                } else{
                    var type_object = data.results[0];
                    var fields = type_object.fields;
                    var type_fields = [];
                    for (var i=0 ; i<fields.fieldNames.length ; i++) {
                        // Splits the string at the first occurrence of '#'(including newlines due to the 's' flag).
                        // The resulting array contains:[ part before the '#', part after '#', '']
                        var fieldType = fields.fieldTypes[i].split(/#(.*)/s);
                        var qualifier = JSON.parse(fieldType[1] || '{}');
                        type_fields.push({
                            name: fields.fieldNames[i],
                            display_name: fields.fieldDisplayNames[i],
                            type: fieldType[0],
                            qualifier: qualifier,
                        })
                    }
                    console.debug("fetch_type_fields(type_id="+type_id+"): abspath="+type_object.abspath+", type_fields=", type_fields);
                    $deferred.resolve(type_fields);
                }
            })
            .fail(function(e){
                $deferred.reject(e.statusText);
            });
        return $deferred.promise();
    }

    function toggle_contols(enabled) {
        $field_drop.toggleClass('disabled', !enabled);
        $refresh_btn.attr('disabled', !enabled);
        $typeObject.attr('disabled', !enabled);
    }

    function clear_displayList() {
        $displayList.find('.del-row').click();
    }
    function add_displayList(field_name) {
        $add_btn.click();
        var $row = $displayList.find('input[name^="displayList"]').last();
        $row.val(field_name).prop('readonly', true);
        return $row;
    }
    function add_fieldList(field) {
        var label = field.name + ' (' + field.display_name+ ')';
        $field_list.append($('<a class="dropdown-item" href="#">').data('field_name', field.name).text(label));
    }
    function open_fieldList() {
        var display_fields = {};
        $displayList.find('input[name^="displayList"]').each(function(i){
            display_fields[$(this).val()] = i;
        });
        $field_list.find('a').each(function(){
            var $item = $(this);
            var field_name = $item.data('field_name');
            $item.toggleClass('disabled', field_name in display_fields);
        });
    }
    function click_fieldList() {
        var $a = $(this);
        if (!$a.parent().hasClass('disabled')) {
            add_displayList($a.data('field_name'));
        }
    }
    function refresh_displayList(type_fields) {
        clear_displayList();
        $.each(type_fields, function(i, field){
            if (!field.qualifier['invisible']) {
                add_displayList(field.name);
            }
        });
    }
    function refresh_fieldList(type_fields) {
        $field_list.empty();
        $.each(type_fields, function(i, field){
            if (!field.qualifier['invisible']) {
                add_fieldList(field);
            }
        });
    }
    function refresh_typeObject(refresh_list, type_id){
        type_id = type_id || $typeObject.val();
        toggle_contols(false);
        $message_box.finish();
        return fetch_type_fields(type_id)
            .done(function(type_fields) {
                if (refresh_list && type_id) {
                    refresh_displayList(type_fields);
                    $message_box.html(msg_refresh_done).css({color: 'blue'}).show().fadeOut(2000);
                }
                refresh_fieldList(type_fields);
            })
            .fail(function(err){
                var msg = '<span class="label label-warning">ERROR</span> ' + msg_refresh_fail;
                if (err) {
                    msg += ' (' + err + ')';
                }
                $message_box.html(msg).css({color: 'red'}).show();
            })
            .always(function(){
                toggle_contols(true);
            });
    }

    //
    // 初期化処理
    //
    // kompira.navigator を一時的に無効にする
    var old_navigator_enabled = kompira.config.navigator.enabled;
    kompira.config.navigator.enabled = false;
    // 表示フィールド名欄を readonly にする
    $displayList.find('input[name^="displayList"]').prop('readonly', true);
    // 追加ボタンを非表示にし、後ろにリフレッシュボタンを追加する
    $add_btn.hide().after($field_btn, $refresh_btn, $message_box);
    //
    // イベントハンドラ追加
    //
    $typeObject.on('select2:select', function(e) {
        // 型オブジェクトが変更されたらリストをリフレッシュする
        refresh_typeObject(true, e.params.data.id);
    });
    $refresh_btn.on('click', function(e) {
        // 「デフォルトに戻す」ボタンが押下されたらリストをリフレッシュする
        refresh_typeObject(true);
    });
    $field_drop.on('click', open_fieldList);
    $field_list.on('click', 'a', click_fieldList);

    // 選択された型オブジェクトのフィールドを取得する
    // ただし更新時(.add でない時)は、表示フィールド一覧は更新しない。
    var refresh_list = !!location.pathname.match(/\.add$/);
    refresh_typeObject(refresh_list)
        .always(function(){
            kompira.config.navigator.enabled = old_navigator_enabled;
        });
});
