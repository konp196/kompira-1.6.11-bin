$(function(){
    $(".delete-checkbox:checkbox").prop('checked', false);
    /* 全選択チェックボックス */
    var $selectAll = $("#selectAll");
    function toggleSelectAll() {
        $selectAll.click();
    }
    $selectAll.prop('checked', false);
    $selectAll.on('change', function(e) {
        var valid_boxes = $(".delete-checkbox:checkbox:not(:disabled)");
        valid_boxes.prop('checked', this.checked);
    });

    function selectableActionModal() {
        /**
         * 選択オブジェクトに対するアクション確認
         */
        var $action_anchor = $(this);
        var $action_modal = $action_anchor.closest('.selectable-action-modal');
        var $action_form = $('#action-form');
        var action = $action_anchor.data('action') || $action_modal.data('action');
        var operation = $action_anchor.data('operation') || $action_modal.data('operation');
        var target = $action_anchor.data('target') || $action_modal.data('target');
        var target_selected = $action_anchor.data('target-selected') || $action_modal.data('target-selected') || target;
        var target_filtered = $action_anchor.data('target-filtered') || $action_modal.data('target-filtered') || target;
        var warning = $action_anchor.data('warning') || $action_modal.data('warning');
        var message = $action_form.find(".modal-body .original_message").text();

        /* action-form にフィルタ条件を追加する */
        var $target_selection = $('<input type="hidden" name="target_selection">');
        var $target_ids = $('<input type="hidden" name="target_ids">');
        var $target_filter = $('<input type="hidden" name="target_filter">');
        /* 処理対象とするオブジェクトを判定する */
        var $selected_objs = $('.delete-checkbox:checkbox:checked');
        var count = 0;
        if ($selected_objs.length > 0) {
            // 選択されたオブジェクトを処理対象にする
            var selected = $.map($selected_objs, function(e){return $(e).val()});
            var target_ids = "" + selected;
            $target_selection.val('target_ids');
            $target_ids.val(target_ids)
            target = target_selected;
            count = selected.length;
            console.log('target_ids[' + count + ']: ' + target_ids);
        } else {
            // フィルタ条件に該当するオブジェクトを処理対象にする
            var query = UTILS.get_url_vars();
            var filter = $.param(query);
            $target_selection.val('target_filter');
            $target_filter.val(filter)
            target = target_filtered;
            // MEMO: 該当オブジェクトの個数をページネータの要素から取得している
            count = $(".paginator .page-count").text();
            console.log('target_filter[' + count + ']: ' + filter);
        }
        if (count > 0) {
            message = message.replace(/\[\[operation\]\]/g, operation);
            message = message.replace(/\[\[target\]\]/g, target);
            message = message.replace(/\[\[count\]\]/g, count);
            $action_form.find('.extra-input').empty().append([$target_selection, $target_ids, $target_filter]);
            $action_form.find(".modal-body .message").toggle(!!message).text(message);
            $action_form.find(".modal-body .warning").toggle(!!warning).find('.warning-text').text(warning);
            $action_form.attr('action', action);
            $action_form.closest('.modal').modal();
        }
    }

    $('.selectable-action-anchor').on('click', function(){
        selectableActionModal.apply(this);
    });
    if (!kompira.keybind.keybinds['a']) {
        kompira.keybind.on('a', toggleSelectAll, gettext('toggle the all objects selection'), 400);
    }
});
