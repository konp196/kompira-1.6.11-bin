// CodeMirror, copyright (c) by Marijn Haverbeke and others
// Distributed under an MIT license: https://codemirror.net/LICENSE

(function(mod) {
  if (typeof exports == "object" && typeof module == "object") // CommonJS
    mod(require("../../lib/codemirror"));
  else if (typeof define == "function" && define.amd) // AMD
    define(["../../lib/codemirror"], mod);
  else // Plain browser env
    mod(CodeMirror);
})(function(CodeMirror) {
    "use strict";
    CodeMirror.defineOption("fullScreen", false, function(cm, val, old) {
        if (old == CodeMirror.Init) old = false;
        if (!old == !val) return;
        var $container = $(cm.getContainerElement());
        if (val) {
            setFullscreen(cm, $container);
        } else {
            setNormal(cm, $container);
        }
    });
    CodeMirror.commands.toggleFullscreen = function(cm) {
        cm.toggleFullscreen();
    };
    CodeMirror.commands.enterFullscreen = function(cm) {
        cm.enterFullscreen();
    };
    CodeMirror.commands.exitFullscreen = function(cm) {
        cm.exitFullscreen();
    };
    CodeMirror.defineExtension("toggleFullscreen", function(options) {
        toggleFullscreen(this);
    });
    CodeMirror.defineExtension("enterFullscreen", function(options) {
        var $container = $(this.getContainerElement());
        if (!$container.hasClass('fullscreen')) {
            setFullscreen(this, $container);
        }
    });
    CodeMirror.defineExtension("exitFullscreen", function(options) {
        var $container = $(this.getContainerElement());
        if (!!$container.hasClass('fullscreen')) {
            setNormal(this, $container);
        }
    });

    function setFullscreen(cm, $container) {
        $(window).scrollTop(0);
        document.documentElement.style.overflow = "hidden";
        $container.addClass("fullscreen");
        $container.closest(".fullscreen-target").addClass("fullscreen");
        cm.refresh();
        cm.focus();
    }

    function setNormal(cm, $container) {
        document.documentElement.style.overflow = "";
        $container.removeClass("fullscreen");
        $container.closest(".fullscreen-target").removeClass("fullscreen");
        cm.refresh();
        cm.focus();
    }

    function toggleFullscreen(cm) {
        var $container = $(cm.getContainerElement());
        if ($container.hasClass('fullscreen')) {
            setNormal(cm, $container);
        } else {
            setFullscreen(cm, $container);
        }
    }
});
