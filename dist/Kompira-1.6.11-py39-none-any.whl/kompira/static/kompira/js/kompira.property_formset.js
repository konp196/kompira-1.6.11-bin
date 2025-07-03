(function(kompira) {
    //
    // グループパーミッション設定フォームにおいて、行追加時に優先度の値を0で初期化する処理
    //
    kompira.property_formset_on_added = function($row) {
        $row.find("input[type=number]").each(function(){
            var $number_input = $(this);
            $number_input.val($number_input.attr('value'));
        });
    };
    kompira.property_formset_mk_option = function(prefix) {
        return {
            prefix: prefix,
            addText: gettext('add another'),
            addCssClass: 'add-row btn btn-secondary btn-sm',
            deleteText: gettext('remove'),
            deleteCssClass: `del-row-${ prefix } btn btn-outline-secondary btn-sm`,
            formCssClass: `dynamic-form-${ prefix }`
        };
    };
})(kompira);
