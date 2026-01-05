// Instant Page Load - Prefetch on Hover
(function () {
    'use strict';

    // Prefetch analyzer page when hovering over the menu
    const analyzerLinks = document.querySelectorAll('a[href="/analyzer"], a[href^="/analyzer?"]');

    analyzerLinks.forEach(link => {
        let prefetched = false;

        link.addEventListener('mouseenter', function () {
            if (!prefetched) {
                prefetched = true;

                // Create invisible iframe to prefetch
                const iframe = document.createElement('iframe');
                iframe.style.display = 'none';
                iframe.src = this.href;
                document.body.appendChild(iframe);

                // Remove after 5 seconds
                setTimeout(() => {
                    if (iframe.parentNode) {
                        iframe.parentNode.removeChild(iframe);
                    }
                }, 5000);

                console.log('🚀 Prefetched:', this.href);
            }
        });
    });

    // Also prefetch on touchstart for mobile
    analyzerLinks.forEach(link => {
        link.addEventListener('touchstart', function () {
            // Prefetch logic same as above
        }, { passive: true });
    });
})();
