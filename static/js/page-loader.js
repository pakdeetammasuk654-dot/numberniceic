// Premium Page Loader for Analyzer
(function () {
    'use strict';

    // Create and inject loader HTML
    function createLoader() {
        const loaderHTML = `
            <div class="page-loader-overlay" id="pageLoader">
                <div class="loader-numbers">
                    <div class="loader-number">1</div>
                    <div class="loader-number">2</div>
                    <div class="loader-number">3</div>
                    <div class="loader-number">4</div>
                    <div class="loader-number">5</div>
                    <div class="loader-number">6</div>
                </div>
                <div class="loader-content">
                    <div class="loader-sun">
                        <div class="loader-sun-core"></div>
                        <div class="loader-sun-rays">
                            <div class="loader-sun-ray"></div>
                            <div class="loader-sun-ray"></div>
                            <div class="loader-sun-ray"></div>
                            <div class="loader-sun-ray"></div>
                            <div class="loader-sun-ray"></div>
                            <div class="loader-sun-ray"></div>
                            <div class="loader-sun-ray"></div>
                            <div class="loader-sun-ray"></div>
                        </div>
                    </div>
                    <h2 class="loader-title">กำลังวิเคราะห์ข้อมูล</h2>
                    <p class="loader-subtitle">กรุณารอสักครู่ ระบบกำลังคำนวณเลขศาสตร์และพลังเงา</p>
                    <div class="loader-progress">
                        <div class="loader-progress-bar"></div>
                    </div>
                </div>
            </div>
        `;

        const div = document.createElement('div');
        div.innerHTML = loaderHTML;
        document.body.appendChild(div.firstElementChild);
    }

    // Show loader
    function showLoader() {
        let loader = document.getElementById('pageLoader');
        if (!loader) {
            createLoader();
            loader = document.getElementById('pageLoader');
        }
        loader.classList.remove('fade-out');
        loader.style.display = 'flex';
    }

    // Hide loader
    function hideLoader() {
        const loader = document.getElementById('pageLoader');
        if (loader) {
            loader.classList.add('fade-out');
            setTimeout(() => {
                loader.style.display = 'none';
            }, 500);
        }
    }

    // Auto-hide on page load
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function () {
            setTimeout(hideLoader, 500);
        });
    } else {
        setTimeout(hideLoader, 500);
    }

    // Show loader on navigation to /analyzer
    document.addEventListener('click', function (e) {
        const link = e.target.closest('a[href="/analyzer"]');
        if (link && !e.ctrlKey && !e.metaKey) {
            showLoader();
        }
    });

    // Expose functions globally
    window.PageLoader = {
        show: showLoader,
        hide: hideLoader
    };
})();
