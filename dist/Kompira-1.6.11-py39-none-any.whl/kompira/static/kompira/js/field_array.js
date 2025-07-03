(function(kompira){
    /** Enhance form submission behavior for forms with the class 'include-unchecked-checkbox'
    * チェックされていない checkbox でも val='false' として POST するようにする
    * 'false' は BooleanField.to_python() で False に変換される
    * Note: Adjusted the orders of form.submit listener registration to ensure it precedes other form.submit listeners.
    */
    $("form.include-unchecked-checkbox").on("submit", function(){

        $(".dynamic-form input[type=checkbox]", this).each(function(){
            var $checkbox = $(this);

            if ($checkbox.is(":checked")) {
                $checkbox.parent().find('input[type=hidden]').remove();
                // Note: When creating a new object (boolean array), there is a scenario where an empty string value may be posted
                // even if the checkbox is checked. To address this, set the checkbox value to 'on'
                $checkbox.val('on');
            } else {
                $hidden = $checkbox.clone();
                $hidden.prop('checked', true);
                $hidden.val('false');
                $hidden.attr('type', 'hidden');
                $hidden.attr('id', '_hidden_' + $checkbox.attr('id'));
                $hidden.insertBefore($checkbox);
            }
        });
    });

    kompira.init_field_array = function() {
        function on_added($row) {
            kompira.init_select2_field($row.find('.django-select2'));
            // $row.find('.django-select2').val(null).trigger('change'); クリアする場合
            /* ClearableFileInput を初期化する */
            $row.find('.clearable').remove();
            kompira.password_field($row.find('.password-form-container'), true);
        };
        /* フィールド編集行のエラー情報のクリア */
        var clear_error = function($row){
            $row.find('.control-group').removeClass('error').find('ul.errorlist').remove();
        };
        var sortable_options = {
            axis: "y",
            containment: "parent",
            items: ">tbody>tr",
            handle: ".sortable-handle",
            cursor: "n-resize",
            opacity: 0.8,
            stop: function(event, ui) {
                $('input:first', ui.item).focus().select();
            }
        };
        var formset_options = {
            addText: gettext('add another'),
            addCssClass: 'add-row btn btn-outline-secondary btn-sm',
            deleteText: gettext('remove'),
            deleteCssClass: 'del-row btn btn-outline-secondary btn-sm',
            added: on_added
        };
        var initialize_formset = function(prefix, sortable, options){
            var form_selector = '#dynamic-form-' + prefix;
            if (sortable) {
                var options = $.extend(true, {}, sortable_options, options);
                $(form_selector).sortable(options);
                $(form_selector).on("formset.added", function(ev, row){
                    $(form_selector).sortable("refresh");
                });
            }
            var options = $.extend({}, formset_options, {prefix: prefix});
            $(form_selector + ' tbody tr').formset(options);
        };
        //
        // [注意]
        //
        // プロパティ編集画面やダイアログにおける formset の初期化 (property.html, dir_view.html) との
        // 重複を避け、field_array.js での formset 初期化を 各種オブジェクト編集やスケジュールフォームに
        // 限定するために、ここでは、CSS セレクタを table 内 table の dynamic フォームに限定している。
        //
        // 将来的に table 内 table にはない dynamic フォームが必要な場合、対象外となるので注意すること。
        //
        $("table table[id^=dynamic-form-]").each(function(){
            var prefix = this.id.replace(/^dynamic-form-/,'');
            var sortable = true;
            initialize_formset(prefix, sortable);
        });
    }
})(kompira);
$(kompira.init_field_array);
