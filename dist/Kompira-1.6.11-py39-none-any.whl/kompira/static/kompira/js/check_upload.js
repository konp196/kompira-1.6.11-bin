(function(kompira){
  kompira.check_upload = function(){
    if (window.File && this.files[0]) {
      var fsize = this.files[0].size;
      var $input = $(this);
      var $alert = $('#id_file_size_alert');
      var limit = $input.data('upload_limit');
      if ($alert) { $alert.remove(); }
      if (fsize > limit) {
        $input.val('');
        $alert = $('#file_size_alert-tmpl').render({});
        $input.after($alert);
      }
    }
  };
})(kompira);

$(function() {
  // アップロードファイルサイズの制限
  $('input[type=file].check_upload').bind('change', kompira.check_upload);
})
