var scrollToElement = (function () {
    var animation,
        animating = false;

    var scrollToElement = function (elem, duration) {
        if (animating || !requestAnimationFrame) {
            return;
        }

        var elemTop = elem.getBoundingClientRect().top,
            scrollY = window.pageYOffset,
            bodyStyle = getComputedStyle(document.body),
            bodyMargin = parseInt(bodyStyle.marginTop) +
                         parseInt(bodyStyle.marginBottom),
            bodyHeight = document.body.offsetHeight + bodyMargin,
            maxScrollY = bodyHeight - window.innerHeight;

        animation = {
            startY: scrollY,
            distanceY: Math.min(elemTop + scrollY, maxScrollY) - scrollY,
            startTime: Date.now(),
            duration: duration,
            prevScrollY: -1,
            hash: "#" + elem.id
        };
        animating = true;
        requestAnimationFrame(step);
    };

    var step = function (timestamp) {
        if (!animating) return;

        var now = timestamp < 1e12 ? Date.now() : timestamp,
            elapsedTime = now - animation.startTime,
            easeCoefficient = swingEase(elapsedTime / animation.duration),
            scrollY = Math.round(animation.startY +
                                 animation.distanceY * easeCoefficient);

        if (elapsedTime >= animation.duration) {
            animating = false;
            // Since we called preventDefault earlier, we must manually update
            // the hash to emulate the native behavior of clicking on a link.
            // It's updated when the animation is over because setting the hash
            // before would scroll the page before the animation plays--the
            // very reason for calling preventDefault.
            location.hash = animation.hash;
        } else {
            if (scrollY != animation.prevScrollY) {
                window.scrollTo(0, scrollY);
            }
            requestAnimationFrame(step);
            animation.prevScrollY = scrollY;
        }
    };

    // jQuery v3.1.1 | (c) jQuery Foundation | jquery.org/license
    // "swing" ease function is from jQuery
    var swingEase = function (t) {
        return 0.5 - Math.cos(t * Math.PI) / 2;
    };

    return scrollToElement;
}());