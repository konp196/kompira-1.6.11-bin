var POLLING = (function (my, $) {
    my.create_polls = function(url, data, callback) {
        return function(){
            var date = new Date();
            var timestamp = date.getTime();
            data.timestamp = timestamp;
            $.ajax({
                url: url,
                dataType: "json",
                data: data,
                traditional: true,
                ifModified: true,
                success : callback
            });
        };
    };
    my.start_polling = function(interval, url, data, callback) {
        var polls = my.create_polls(url, data, callback);
        polls();
        setInterval(polls, interval);
    };
    return my;
})({}, jQuery);
