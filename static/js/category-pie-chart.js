// Initialize globals immediately
window.defaultLuckyIcons = window.defaultLuckyIcons || {};
window.luckyIndices = window.luckyIndices || {};

// DEFINE INIT FUNCTION FIRST to prevent "is not a function" errors
window.initNestedDonut = function (id, data, activeCategoriesJSON) {
    let attempts = 0;
    const maxAttempts = 60;

    function tryInit() {
        const svg = document.getElementById(id);

        // FAILSAFE: Force hide skeleton immediately if we can find it
        // This runs before anything else to ensure "Instant" feel
        const isModal = id.startsWith('modal-');
        const nameType = id.replace(isModal ? 'modal-nested-donut-' : 'nested-donut-', '');
        const skeleton = document.getElementById('skeleton-html-' + nameType);
        if (skeleton) {
            skeleton.style.display = 'none'; // Nuclear option
        }

        if (!svg) {
            attempts++;
            if (attempts < maxAttempts) {
                requestAnimationFrame(tryInit);
            }
            return;
        }
        setupChart(svg);
    }

    function setupChart(svg) {
        try {
            let breakdownJSON = "{}";
            if (typeof data === 'object') {
                breakdownJSON = JSON.stringify(data);
            } else if (typeof data === 'string') {
                if (data.trim().startsWith('{') || data.trim().startsWith('[')) {
                    // It's likely raw JSON, not Base64
                    breakdownJSON = data;
                } else {
                    // Assume Base64 (Legacy/Standard path)
                    try {
                        const binaryString = atob(data);
                        const bytes = new Uint8Array(binaryString.length);
                        for (let i = 0; i < binaryString.length; i++) {
                            bytes[i] = binaryString.charCodeAt(i);
                        }
                        breakdownJSON = new TextDecoder().decode(bytes);
                    } catch (e) {
                        console.warn("[Donut] Base64 decode failed, using raw:", e);
                        breakdownJSON = data;
                    }
                }
            }
            svg.dataset.breakdown = breakdownJSON;
        } catch (e) {
            console.error("[Donut] Data parse error", e);
        }
        svg.dataset.activeCategories = (typeof activeCategoriesJSON === 'object') ? JSON.stringify(activeCategoriesJSON) : activeCategoriesJSON;
        svg.dataset.luckyCategories = JSON.stringify([]);
        const innerRing = svg.querySelector('.inner-ring');
        if (!innerRing) return;

        function calculatePercentages() {
            const breakdown = JSON.parse(svg.dataset.breakdown || '{}');
            const lucky = JSON.parse(svg.dataset.luckyCategories || '[]');

            const percentages = { 'สุขภาพ': 0, 'การงาน': 0, 'การเงิน': 0, 'ความรัก': 0, 'N/A': 0 };
            const categories = ['สุขภาพ', 'การงาน', 'การเงิน', 'ความรัก'];

            // 1. Assign Base Natural Scores (25% each if good)
            let usedScore = 0;
            categories.forEach(cat => {
                // Check for direct key match or case-insensitive match just in case
                let data = breakdown[cat];
                if (!data) {
                    // Fallback search
                    const key = Object.keys(breakdown).find(k => k === cat);
                    data = breakdown[key];
                }

                if ((data?.good || 0) > 0 || (data?.Good || 0) > 0) { // Handle Go struct field casing if JSON is capitalized
                    percentages[cat] = 25;
                    usedScore += 25;
                }
            });

            // 2. Distribute Remaining Score to Lucky Categories (Additive Bonus)
            const activeLucky = lucky.filter(cat => categories.includes(cat));
            if (activeLucky.length > 0) {
                let remaining = 100 - usedScore;
                if (remaining < 0) remaining = 0; // Just in case

                const bonusPerCat = remaining / activeLucky.length;
                activeLucky.forEach(cat => {
                    percentages[cat] += bonusPerCat;
                });
            }

            // 3. Calculate N/A
            let finalTotal = 0;
            categories.forEach(cat => finalTotal += percentages[cat]);

            if (finalTotal < 99.9) {
                percentages['N/A'] = 100 - finalTotal;
            }

            return percentages;
        }

        function createArcPath(cx, cy, radius, thickness, startAngle, endAngle) {
            if (endAngle - startAngle >= 359.9) endAngle = startAngle + 359.99;
            const innerRadius = radius;
            const outerRadius = radius + thickness;
            const startRad = (startAngle * Math.PI) / 180;
            const endRad = (endAngle * Math.PI) / 180;
            const x1 = cx + outerRadius * Math.cos(startRad);
            const y1 = cy + outerRadius * Math.sin(startRad);
            const x2 = cx + outerRadius * Math.cos(endRad);
            const y2 = cy + outerRadius * Math.sin(endRad);
            const x3 = cx + innerRadius * Math.cos(endRad);
            const y3 = cy + innerRadius * Math.sin(endRad);
            const x4 = cx + innerRadius * Math.cos(startRad);
            const y4 = cy + innerRadius * Math.sin(startRad);
            const largeArc = endAngle - startAngle > 180 ? 1 : 0;
            return `M ${x1} ${y1} A ${outerRadius} ${outerRadius} 0 ${largeArc} 1 ${x2} ${y2} L ${x3} ${y3} A ${innerRadius} ${innerRadius} 0 ${largeArc} 0 ${x4} ${y4} Z`;
        }

        // Initialize state variables
        svg._serverRenderPreserved = true;
        svg._initialLoadComplete = false;

        function drawCategoryPie(animate = false, forceWipe = false) {
            const isModal = svg.id.startsWith('modal-');
            const nameFromId = svg.id.replace(isModal ? 'modal-nested-donut-' : 'nested-donut-', '');

            if (!forceWipe && !svg._initialLoadComplete) {
                svg._lastPercentages = calculatePercentages();
                svg._initialLoadComplete = true;
                return;
            }

            svg._serverRenderPreserved = false;
            const targetPercentages = calculatePercentages();

            if (animate) {
                let startState = svg._lastPercentages || targetPercentages;

                // Compare states: if they are identical, provide "running" feedback by dipping
                let isSame = true;
                const categories = ['สุขภาพ', 'การงาน', 'การเงิน', 'ความรัก', 'N/A'];
                for (let cat of categories) {
                    if (Math.abs((startState[cat] || 0) - (targetPercentages[cat] || 0)) > 0.1) {
                        isSame = false;
                        break;
                    }
                }

                if (isSame) {
                    // Force a dip animation so the graph "runs" even if the value is the same
                    startState = {};
                    categories.forEach(cat => {
                        startState[cat] = (targetPercentages[cat] || 0) * 0.85;
                    });
                }

                animatePie(startState, targetPercentages);
            } else {
                svg._lastPercentages = targetPercentages;
                renderPie(targetPercentages);
            }
        }

        function animatePie(start, end) {
            const duration = 450; // ms
            const startTime = performance.now();
            const categories = ['สุขภาพ', 'การงาน', 'การเงิน', 'ความรัก', 'N/A'];

            function step(currentTime) {
                const elapsed = currentTime - startTime;
                const progress = Math.min(elapsed / duration, 1);

                // Easing (OutQuad)
                const t = progress * (2 - progress);

                const current = {};
                categories.forEach(cat => {
                    const s = start[cat] || 0;
                    const e = end[cat] || 0;
                    current[cat] = s + (e - s) * t;
                });

                renderPie(current);

                if (progress < 1) {
                    svg._animId = requestAnimationFrame(step);
                } else {
                    svg._lastPercentages = end;
                }
            }

            if (svg._animId) cancelAnimationFrame(svg._animId);
            svg._animId = requestAnimationFrame(step);
        }

        const idPrefix = 'donut-' + Math.random().toString(36).substr(2, 6);

        function renderPie(percentages) {
            const isModal = svg.id.startsWith('modal-');
            const nameFromId = svg.id.replace(isModal ? 'modal-nested-donut-' : 'nested-donut-', '');

            // Hide skeleton if present (Redundant safekeeping for manual calls)
            const skeleton = document.getElementById('skeleton-html-' + nameFromId);
            if (skeleton) {
                skeleton.style.opacity = '0'; // Instant hide if we are redrawing manually
                skeleton.style.display = 'none';
            }

            // Show center text if it was hidden
            const staticTexts = svg.querySelectorAll('.center-text-group');
            staticTexts.forEach(el => el.style.display = 'block');

            // Standard render logic continues...
            innerRing.innerHTML = '';
            const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');

            const filter = document.createElementNS('http://www.w3.org/2000/svg', 'filter');
            filter.setAttribute('id', idPrefix + '-dropShadow');
            filter.innerHTML = `<feGaussianBlur in="SourceAlpha" stdDeviation="3"/><feOffset dx="0" dy="2" result="offsetblur"/><feComponentTransfer><feFuncA type="linear" slope="0.3"/></feComponentTransfer><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>`;
            defs.appendChild(filter);

            const catMap = { 'สุขภาพ': 'H', 'การงาน': 'W', 'การเงิน': 'F', 'ความรัก': 'L', 'N/A': 'N' };
            const gradientConfigs = {
                'การงาน': ['#90CAF9', '#42A5F5', '0'],
                'การเงิน': ['#FFCC80', '#FFA726', '-45'],
                'ความรัก': ['#F48FB1', '#EC407A', '45'],
                'สุขภาพ': ['#80CBC4', '#26A69A', '90'],
                'N/A': ['#F1F5F9', '#E2E8F0', '0']
            };

            for (const [cat, colors] of Object.entries(gradientConfigs)) {
                const gradId = idPrefix + '-' + (catMap[cat] || 'X');
                const grad = document.createElementNS('http://www.w3.org/2000/svg', 'linearGradient');
                grad.setAttribute('id', gradId);
                grad.setAttribute('gradientTransform', `rotate(${colors[2]})`);
                const s1 = document.createElementNS('http://www.w3.org/2000/svg', 'stop');
                s1.setAttribute('offset', '0%'); s1.setAttribute('stop-color', colors[0]);
                const s2 = document.createElementNS('http://www.w3.org/2000/svg', 'stop');
                s2.setAttribute('offset', '100%'); s2.setAttribute('stop-color', colors[1]);
                grad.appendChild(s1); grad.appendChild(s2);
                defs.appendChild(grad);
            }

            const goldGrad = document.createElementNS('http://www.w3.org/2000/svg', 'linearGradient');
            goldGrad.setAttribute('id', idPrefix + '-gold');
            goldGrad.setAttribute('x1', '0%'); goldGrad.setAttribute('y1', '0%');
            goldGrad.setAttribute('x2', '100%'); goldGrad.setAttribute('y2', '100%');
            goldGrad.innerHTML = `<stop offset="0%" style="stop-color:#D97706;"/><stop offset="50%" style="stop-color:#FFD700;"/><stop offset="100%" style="stop-color:#B45309;"/>`;
            defs.appendChild(goldGrad);
            innerRing.appendChild(defs);

            const radius = 68;
            const thickness = 28;
            let currentAngle = -90;

            const categories = ['สุขภาพ', 'การงาน', 'การเงิน', 'ความรัก', 'N/A'];
            categories.forEach(cat => {
                const pct = percentages[cat] || 0;
                if (pct <= 0) return;
                const angleRange = (pct / 100) * 360;
                const gradId = idPrefix + '-' + (catMap[cat] || 'X');
                const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
                path.setAttribute('d', createArcPath(100, 100, radius, thickness, currentAngle, currentAngle + angleRange));
                path.setAttribute('fill', (cat === 'N/A') ? '#F1F5F9' : `url(#${gradId})`);
                innerRing.appendChild(path);

                // ADD TEXT LABEL ON SLICE
                if (pct >= 6 && cat !== 'N/A') { // Only show label if slice is big enough and NOT N/A
                    const midAngle = currentAngle + angleRange / 2;
                    const textRadius = radius + (thickness / 2); // Center of the ring thickness
                    const rad = (midAngle * Math.PI) / 180;
                    const tx = 100 + textRadius * Math.cos(rad);
                    const ty = 100 + textRadius * Math.sin(rad);

                    const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
                    text.setAttribute('x', tx);
                    text.setAttribute('y', ty);
                    text.setAttribute('text-anchor', 'middle');
                    text.setAttribute('dominant-baseline', 'middle');
                    text.setAttribute('font-size', '10px');
                    text.setAttribute('font-weight', 'bold');
                    text.setAttribute('fill', (cat === 'N/A') ? '#94A3B8' : '#FFFFFF');
                    text.setAttribute('style', 'pointer-events: none; text-shadow: 0px 1px 2px rgba(0,0,0,0.3);');
                    text.textContent = Math.round(pct) + '%';
                    innerRing.appendChild(text);
                }

                currentAngle += angleRange;
            });

            const centerGroup = document.createElementNS('http://www.w3.org/2000/svg', 'g');
            const hole = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
            hole.setAttribute('cx', '100'); hole.setAttribute('cy', '100'); hole.setAttribute('r', '58');
            hole.setAttribute('fill', 'white');
            hole.setAttribute('style', `filter: drop-shadow(0 4px 10px rgba(0,0,0,0.12));`);
            centerGroup.appendChild(hole);

            // Robust Total Score Calculation
            let totalScore = 0;
            ['สุขภาพ', 'การงาน', 'การเงิน', 'ความรัก'].forEach(c => {
                totalScore += (percentages[c] || 0);
            });
            console.log("Chart Percentages:", percentages, "Total:", totalScore);

            const centerScoreText = svg.querySelector('.donut-center-number');
            if (centerScoreText) {
                centerScoreText.textContent = Math.round(totalScore) + '%';
            }
            // centerLabel check removed to support clean center
            // const centerLabel = svg.querySelector('.donut-center-label');
            // if (centerLabel) {
            //     centerLabel.textContent = 'คะแนนดีรวม';
            // }

            innerRing.appendChild(centerGroup);

            categories.slice(0, 4).forEach(cat => {
                let pct = percentages[cat] || 0;
                const tid = isModal ? ('modal-good-score-container-' + nameFromId + '-' + cat) : ('good-score-container-' + nameFromId + '-' + cat);
                const el = document.getElementById(tid);

                if (el) {
                    const lucky = JSON.parse(svg.dataset.luckyCategories || '[]');
                    const isLucky = lucky.includes(cat);

                    const catColor = (gradientConfigs[cat] && gradientConfigs[cat][1]) || '#10B981';
                    if (isLucky) {
                        el.innerHTML = `<span style="color: ${catColor}; font-weight: 800; font-size: 1.1rem;">${Math.round(pct)}%</span>`;
                    } else {
                        el.innerHTML = `<span style="color: ${pct > 0 ? catColor : '#CBD5E1'}; font-weight: 700;">${Math.round(pct)}%</span>`;
                    }
                }
            });

            // Update External Total Score Elements (Bottom Bar / Header)
            // Target the template ID: total-score-NAME
            // Update Center Text
            const centerScoreNumber = svg.querySelector('.donut-center-number');
            if (centerScoreNumber) {
                centerScoreNumber.textContent = Math.round(totalScore) + '%';
            }

            // Update External Total Score Elements (Bottom Bar / Header)
            const globalScoreElements = document.querySelectorAll('[id^="total-score-' + nameFromId + '"] .score-value');
            globalScoreElements.forEach(el => {
                el.textContent = Math.round(totalScore) + '%';
            });
        }

        svg.addLuckyCategory = function (category) {
            const lucky = JSON.parse(svg.dataset.luckyCategories || '[]');
            if (!lucky.includes(category)) {
                lucky.push(category);
                svg.dataset.luckyCategories = JSON.stringify(lucky);
                // User interaction: Force redraw and allow animation
                drawCategoryPie(true, true);
            }
        };

        // EXPOSE REDRAW for external updates (e.g. from updateScores)
        svg.redraw = function (animate) {
            drawCategoryPie(animate);
        };

        // INITIAL LOAD: 
        svg._serverRenderPreserved = true;
        svg._initialLoadComplete = true; // Ready for interaction
        svg._lastPercentages = calculatePercentages();

        // We are done. We rely 100% on SSR for the initial view.
    }

    // Start the init loop
    tryInit();
};

function updateScores(containerId) {
    if (!containerId || typeof containerId !== 'string') return;

    var isModal = containerId.startsWith('modal-');
    var parts = containerId.split('-');
    var cat = parts.pop();
    var nameParts = isModal ? parts.slice(3) : parts.slice(2);
    var name = nameParts.join('-');

    var prefix = isModal ? ('modal-lucky-container-' + name + '-') : ('lucky-container-' + name + '-');
    var luckyCats = [];

    document.querySelectorAll("[id^='" + prefix + "']").forEach(function (el) {
        if (el.getAttribute('data-showing-number') === 'true') {
            var p = el.id.split('-');
            luckyCats.push(p.pop());
        }
    });

    // Find ALL SVGs for this name (Desktop/Modal/etc)
    var desktopSvgId = 'nested-donut-' + name;
    var modalSvgId = 'modal-nested-donut-' + name;
    var svgs = [document.getElementById(desktopSvgId), document.getElementById(modalSvgId)].filter(s => s !== null);

    svgs.forEach(function (svg) {
        svg.dataset.luckyCategories = JSON.stringify(luckyCats);
        if (typeof svg.redraw === 'function') {
            svg.redraw(true);
        }
    });
}

window.toggleLuckyNumber = async function (category, containerId) {
    var container = document.getElementById(containerId);
    if (!container) return;

    container.style.transition = 'opacity 0.3s ease-in-out';

    // Capture initial state (Empty div or Modal Badge)
    if (window.defaultLuckyIcons[containerId] === undefined) {
        // Validation: If it currently contains a phone number (e.g. from a previous failed states), 
        // don't capture that. But initially it should be empty or the badge.
        const currentHTML = container.innerHTML;
        if (!currentHTML.includes('font-size: 2.2rem')) { // Simple check to avoid capturing a number
            window.defaultLuckyIcons[containerId] = currentHTML;
        } else {
            window.defaultLuckyIcons[containerId] = ""; // Fallback to empty
        }
    }

    var nextIndex = 0;
    if (container.getAttribute('data-showing-number') === 'true') {
        var currentIndex = window.luckyIndices[containerId] || 0;
        nextIndex = currentIndex + 1;
    }
    window.luckyIndices[containerId] = nextIndex;

    const fade = async (toOpacity) => {
        container.style.opacity = toOpacity;
        await new Promise(r => setTimeout(r, 200)); // Speed up animation
    };

    try {
        await fade('0');

        // Skeleton Loader
        container.innerHTML = `
            <div class="lucky-skeleton" style="width: 100%; height: 255px; background: #fff; border-top: 1px solid #E2E8F0; border-bottom: 1px solid #E2E8F0; padding: 32px 24px; display: flex; flex-direction: column; gap: 20px; position: relative; overflow: hidden; box-sizing: border-box; margin: 4px 0;">
                <div style="height: 16px; width: 65%; background: #F1F5F9; border-radius: 8px; align-self: center; position: relative; overflow: hidden;"><div class="shimmer" style="position: absolute; top:0; left:0; width:100%; height:100%; background: linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent); animation: lucky-shimmer 1.5s infinite;"></div></div>
                <div style="height: 45px; width: 90%; background: #F1F5F9; border-radius: 12px; align-self: center; position: relative; overflow: hidden;"><div class="shimmer" style="position: absolute; top:0; left:0; width:100%; height:100%; background: linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent); animation: lucky-shimmer 1.5s infinite;"></div></div>
                <div style="height: 25px; width: 40%; background: #F1F5F9; border-radius: 8px; align-self: center; position: relative; overflow: hidden;"><div class="shimmer" style="position: absolute; top:0; left:0; width:100%; height:100%; background: linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent); animation: lucky-shimmer 1.5s infinite;"></div></div>
                <div style="display: flex; gap: 12px; margin-top: auto;">
                    <div style="height: 45px; flex: 2; background: #F1F5F9; border-radius: 14px; position: relative; overflow: hidden;"><div class="shimmer" style="position: absolute; top:0; left:0; width:100%; height:100%; background: linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent); animation: lucky-shimmer 1.5s infinite;"></div></div>
                    <div style="height: 45px; flex: 1; background: #F1F5F9; border-radius: 14px; position: relative; overflow: hidden;"><div class="shimmer" style="position: absolute; top:0; left:0; width:100%; height:100%; background: linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent); animation: lucky-shimmer 1.5s infinite;"></div></div>
                </div>
                <style>
                    @keyframes lucky-shimmer {
                        0% { transform: translateX(-100%); }
                        100% { transform: translateX(100%); }
                    }
                </style>
            </div>
        `;

        await fade('1');

        const response = await fetch('/api/lucky-number?category=' + encodeURIComponent(category) + '&index=' + nextIndex);
        if (!response.ok) throw new Error('Network response was not ok');
        const data = await response.json();

        if (data && data.number) {
            var keywordsHtml = '';
            if (data.keywords && data.keywords.length > 0) {
                keywordsHtml = '<div style="font-size: 0.95rem; color: #475569; margin-bottom: 8px; font-weight: 300; line-height: 1.4; font-family: \'Kanit\', sans-serif;">' + data.keywords.join(', ') + '</div>';
            }

            var html = '<div style="width: 100%; box-sizing: border-box; margin: 4px 0; padding: 22px 16px; background: #FFFBEB; border-top: 1px solid #FCD34D; border-bottom: 1px solid #FCD34D; text-align: center; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.05); position: relative; overflow: hidden;">' +
                keywordsHtml +
                '<div style="font-weight: 300; font-size: 2.3rem; letter-spacing: 1.5px; margin: 10px 0 15px 0; font-family: \'Kanit\', sans-serif; color: #D97706;">' + data.number + '</div>' +
                '<div style="display: flex; justify-content: center; align-items: center; gap: 10px; margin-bottom: 20px; font-family: \'Kanit\', sans-serif;">' +
                '<div style="font-size: 0.95rem; color: #92400E; background: rgba(251, 191, 36, 0.3); padding: 5px 14px; border-radius: 12px; font-weight: 300;">ผลรวม <b>' + (data.sum || '-') + '</b></div>' +
                '<a href="/number-analysis?number=' + data.number + '" target="_blank" style="text-decoration: none; font-size: 0.9rem; color: #4F46E5; font-weight: 400; background: #fff; padding: 5px 14px; border-radius: 12px; border: 1px solid #E5E7EB; border-bottom: 2px solid #D1D5DB; display: flex; align-items: center; gap: 6px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); transition: all 0.2s; font-family: \'Kanit\', sans-serif;">' +
                '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>' +
                'วิเคราะห์' +
                '</a>' +
                '</div>' +
                '<div style="display: flex; gap: 14px; padding: 0 10px; font-family: \'Kanit\', sans-serif;">' +
                '<button onclick="window.openPurchaseModal(\'' + data.number + '\')" style="flex: 2; background: linear-gradient(135deg, #F59E0B 0%, #D97706 100%); color: white; border: none; padding: 14px; border-radius: 16px; font-weight: 400; cursor: pointer; font-size: 1rem; box-shadow: 0 4px 6px rgba(217, 119, 6, 0.2); transition: transform 0.1s; font-family: \'Kanit\', sans-serif;" onmousedown="this.style.transform=\'scale(0.98)\'" onmouseup="this.style.transform=\'scale(1)\'">สั่งซื้อเลขนี้</button>' +
                '<button onclick="window.revertLuckyNumber(\'' + containerId + '\')" style="flex: 1; background: #fff; color: #64748B; border: 1px solid #E5E7EB; padding: 14px; border-radius: 16px; font-weight: 400; cursor: pointer; font-size: 0.95rem; font-family: \'Kanit\', sans-serif;">ยกเลิก</button>' +
                '</div>' +
                '</div>';

            await fade('0');
            container.innerHTML = html;
            container.setAttribute('data-showing-number', 'true');
            await fade('1');

            updateScores(containerId);
        } else {
            // Handle case where no number is found
            console.warn('No lucky number found for category:', category);
            await fade('0');
            container.innerHTML = '<div style="color: #64748B; padding: 20px; text-align: center; font-size: 0.9rem;">ไม่พบเบอร์มงคลในหมวดนี้</div>';
            await fade('1');
            setTimeout(() => window.revertLuckyNumber(containerId), 2000);
        }
    } catch (error) {
        console.error('Error fetching lucky number:', error);
        await fade('0');
        container.innerHTML = '<div style="color: red; padding: 10px; text-align: center; font-size: 0.85rem;">เกิดข้อผิดพลาด กรุณาลองใหม่</div>';
        await fade('1');

        // Auto revert after 2 seconds
        setTimeout(() => window.revertLuckyNumber(containerId), 2000);
    }
};

window.revertLuckyNumber = function (containerId) {
    console.log("[Lucky] Reverting container:", containerId);
    var container = document.getElementById(containerId);
    if (!container) {
        console.error("[Lucky] Container not found:", containerId);
        return;
    }

    // Retrieve initial state
    var initialHTML = window.defaultLuckyIcons[containerId];
    if (initialHTML === undefined) {
        console.warn("[Lucky] No initial state saved for:", containerId);
        initialHTML = ""; // Default fallback
    }

    // REVERT IMMEDIATELY
    container.innerHTML = initialHTML;
    container.setAttribute('data-showing-number', 'false');
    container.style.opacity = '1';

    // Sync with graph and other UI elements
    updateScores(containerId);
};

window.openPurchaseModal = function (phoneNumber) {
    var modal = document.getElementById('purchase-modal');
    if (modal) {
        var container = document.getElementById('buy-modal-phone');
        if (container) {
            container.innerText = phoneNumber;
        }
    }
    if (modal) modal.style.display = 'flex';
};

window.handleLuckyClick = function (cat, containerId, donutId) {
    console.log("[HandleLuckyClick] Called for:", cat, containerId);
    if (typeof window.toggleLuckyNumber === "function") {
        window.toggleLuckyNumber(cat, containerId);
    } else {
        console.error("[HandleLuckyClick] toggleLuckyNumber is not a function!");
        alert("Error: toggleLuckyNumber function missing. Please refresh.");
    }
};
