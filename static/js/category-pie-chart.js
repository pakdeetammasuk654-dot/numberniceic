window.defaultLuckyIcons = window.defaultLuckyIcons || {};
window.luckyIndices = window.luckyIndices || {};

function updateScores(containerId) {
    if (!containerId || typeof containerId !== 'string') return;

    var isModal = containerId.startsWith('modal-');
    var parts = containerId.split('-');
    // Expected format: lucky-container-NAME-CATEGORY or modal-lucky-container-NAME-CATEGORY
    var cat = parts.pop();
    var nameParts = isModal ? parts.slice(3) : parts.slice(2);
    var name = nameParts.join('-');

    var prefix = isModal ? ('modal-lucky-container-' + name + '-') : ('lucky-container-' + name + '-');
    var luckyCats = [];

    // Collect all active lucky categories
    document.querySelectorAll("[id^='" + prefix + "']").forEach(function (el) {
        if (el.getAttribute('data-showing-number') === 'true') {
            var p = el.id.split('-');
            luckyCats.push(p.pop());
        }
    });

    var svgId = isModal ? ('modal-nested-donut-' + name) : ('nested-donut-' + name);
    var svg = document.getElementById(svgId);

    if (svg) {
        // Updated logic: Save lucky categories to dataset so calculatePercentages can read it
        svg.dataset.luckyCategories = JSON.stringify(luckyCats);

        // Use the existing logic to recalculate and redraw everything
        if (typeof svg.redraw === 'function') {
            svg.redraw(); // This will trigger drawCategoryPie -> calculatePercentages
        }
    }
}

async function toggleLuckyNumber(category, containerId) {
    console.log("Fetching lucky number for:", category);
    var container = document.getElementById(containerId);
    if (!container) return;

    if (!window.defaultLuckyIcons[containerId]) {
        window.defaultLuckyIcons[containerId] = container.innerHTML;
    }

    var nextIndex = 0;
    if (container.getAttribute('data-showing-number') === 'true') {
        var currentIndex = window.luckyIndices[containerId] || 0;
        nextIndex = currentIndex + 1;
    }
    window.luckyIndices[containerId] = nextIndex;

    try {
        container.innerHTML = '<div class="animate-spin" style="width: 20px; height: 20px; border: 2px solid #ccc; border-top-color: #333; border-radius: 50%; margin: 10px auto;"></div>';

        const response = await fetch('/api/lucky-number?category=' + encodeURIComponent(category) + '&index=' + nextIndex);

        if (!response.ok) {
            throw new Error('Server returned ' + response.status);
        }

        const data = await response.json();

        if (data && data.number) {
            var keywordsHtml = '';
            if (data.keywords && data.keywords.length > 0) {
                keywordsHtml = '<div style="font-size: 0.75rem; color: #555; margin-bottom: 6px; font-weight: 500;">' + data.keywords.join(', ') + '</div>';
            }

            var html = '<div style="width: 100%; box-sizing: border-box; margin: 8px 0; padding: 16px 12px; background: #FFFBEB; border: 1px solid #FCD34D; border-radius: 16px; text-align: center; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05); position: relative; overflow: hidden; animation: fadeIn 0.5s ease-out;">' +
                '<style>@keyframes shimmerText { 0% { background-position: -200% center; } 100% { background-position: 200% center; } }</style>' +
                '<div style="position: absolute; top: 0; left: 0; width: 100%; height: 6px; background: linear-gradient(90deg, #F59E0B, #FBBF24, #FFF7ED, #FBBF24, #F59E0B); background-size: 200% auto; animation: shimmerText 3s linear infinite;"></div>' +

                // Keyword display
                keywordsHtml +

                // Golden Number
                '<div style="font-weight: 800; font-size: 2.2rem; letter-spacing: 2px; margin: 8px 0 12px 0; font-family: \'Sarabun\', sans-serif; ' +
                'background: linear-gradient(180deg, #D97706 0%, #F59E0B 40%, #B45309 100%); ' +
                '-webkit-background-clip: text; -webkit-text-fill-color: transparent; filter: drop-shadow(0 2px 2px rgba(180, 83, 9, 0.15)); ' +
                '">' + data.number + '</div>' +

                // Sum & Power Badge
                '<div style="font-size: 0.85rem; color: #92400E; display: flex; align-items: center; justify-content: center; gap: 8px; margin-bottom: 12px;">' +
                '<span style="background: rgba(251, 191, 36, 0.3); padding: 2px 8px; border-radius: 6px;">ผลรวม <b>' + (data.sum || '-') + '</b></span>' +
                '<span style="color: #B45309; font-weight: 800; display: flex; align-items: center; gap: 4px;">เบอร์ VIP ✨</span>' +
                '</div>' +

                // Action Buttons container
                '<div style="display: flex; align-items: center; justify-content: center; gap: 10px; margin-top: 12px; padding-top: 12px; border-top: 1px dashed rgba(180, 83, 9, 0.2);">' +

                // 1. Buy Button
                '<button onclick="event.stopPropagation(); window.openPurchaseModal(\'' + data.number + '\')" style="flex: 1; background: linear-gradient(135deg, #059669 0%, #10B981 100%); color: white; border: none; padding: 8px 12px; border-radius: 12px; font-size: 0.85rem; font-weight: 700; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 6px; box-shadow: 0 4px 6px -1px rgba(5, 150, 105, 0.4); text-decoration: none; transition: transform 0.1s;">' +
                '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/><path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"/></svg> ซื้อเลย' +
                '</button>' +

                // 2. Analyze Button (Icon only or small text)
                '<a href="/number-analysis?number=' + data.number + '" target="_blank" onclick="event.stopPropagation();" style="background: white; color: #4F46E5; border: 1px solid #E0E7FF; padding: 8px 12px; border-radius: 12px; font-size: 0.85rem; font-weight: 600; display: flex; align-items: center; justify-content: center; gap: 6px; text-decoration: none; box-shadow: 0 2px 4px rgba(0,0,0,0.05);">' +
                '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg> วิเคราะห์' +
                '</a>' +

                // 3. Delete Button (Small Icon)
                '<button onclick="event.stopPropagation(); revertLuckyNumber(\'' + containerId + '\')" title="ลบเบอร์" style="background: #FEF2F2; color: #EF4444; border: 1px solid #FECACA; width: 32px; height: 32px; border-radius: 12px; display: flex; align-items: center; justify-content: center; cursor: pointer;">' +
                '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6L6 18M6 6l12 12"/></svg>' +
                '</button>' +

                '</div>' + // End actions
                '</div>';
            container.innerHTML = html;
            container.setAttribute('data-showing-number', 'true');
            updateScores(containerId);
        } else {
            console.warn("No number returned for category:", category);
            alert("ไม่มีเบอร์มงคลเพิ่มเติมในหมวดนี้");
            revertLuckyNumber(containerId);
        }
    } catch (e) {
        console.error("Fetch Error:", e);
        alert("ไม่สามารถดึงเบอร์มงคลได้: " + e.message);
        revertLuckyNumber(containerId);
    }
}

function revertLuckyNumber(containerId) {
    var container = document.getElementById(containerId);
    if (container && window.defaultLuckyIcons[containerId]) {
        container.innerHTML = window.defaultLuckyIcons[containerId];
        container.removeAttribute('data-showing-number');
        updateScores(containerId);
    }
}

function openPurchaseModal(phoneNumber) {
    var modal = document.getElementById('purchase-modal');
    if (phoneNumber) {
        var container = document.getElementById('buy-modal-phone');
        if (container) {
            container.innerText = phoneNumber;
        }
    }
    if (modal) modal.style.display = 'flex';
}

// -- New functionality for Nested Donut --
window.handleLuckyClick = function (cat, containerId, donutId) {
    if (typeof toggleLuckyNumber === "function") toggleLuckyNumber(cat, containerId);
    var svg = document.getElementById(donutId);
    if (svg && svg.addLuckyCategory) svg.addLuckyCategory(cat);
}

window.initNestedDonut = function (id, data, activeCategoriesJSON) {
    // Retry mechanism with exponential backoff
    let attempts = 0;
    const maxAttempts = 10;

    function tryInit() {
        attempts++;

        try {
            console.log('[Nested Donut] Attempt', attempts, 'for ID:', id);

            var breakdown;
            try {
                breakdown = JSON.parse(atob(data));
            } catch (e) {
                console.error("Failed to parse base64 data", e);
                return;
            }

            const svg = document.getElementById(id);
            if (!svg) {
                if (attempts < maxAttempts) {
                    const delay = Math.min(100 * Math.pow(2, attempts - 1), 2000); // Exponential backoff, max 2s
                    console.warn('[Nested Donut] SVG not found, retrying in', delay, 'ms');
                    setTimeout(tryInit, delay);
                    return;
                }
                console.error('[Nested Donut] SVG not found after', maxAttempts, 'attempts:', id);
                return;
            }

            console.log('[Nested Donut] SVG found, initializing:', id);

            const activeCategories = JSON.parse(activeCategoriesJSON);
            console.log('[Category Pie] Active categories:', activeCategories);
            svg.dataset.activeCategories = activeCategoriesJSON;
            svg.dataset.luckyCategories = JSON.stringify([]);
            const innerRing = svg.querySelector('.inner-ring');

            // Hide center text elements
            const centerNumber = svg.querySelector('.donut-center-number');
            const centerLabel = svg.querySelector('.donut-center-label');
            if (centerNumber) centerNumber.style.display = 'none';
            if (centerLabel) centerLabel.style.display = 'none';

            function calculatePercentages() {
                const active = JSON.parse(svg.dataset.activeCategories || '[]');
                const lucky = JSON.parse(svg.dataset.luckyCategories || '[]');
                const percentages = {};

                // 1. Base Active (25% each)
                active.forEach(cat => { percentages[cat] = 25; });

                // 2. Calculate Gap
                let currentTotal = 0;
                for (let k in percentages) currentTotal += percentages[k];
                let gap = 100 - currentTotal;

                // 3. Distribute Gap to Lucky Numbers
                if (lucky.length > 0 && gap > 0) {
                    let bonus = gap / lucky.length;
                    lucky.forEach(cat => {
                        percentages[cat] = (percentages[cat] || 0) + bonus;
                    });
                } else if (gap > 0) {
                    // No lucky numbers, leave as N/A
                    percentages['N/A'] = gap;
                }

                return percentages;
            }

            function createArcPath(cx, cy, radius, thickness, startAngle, endAngle) {
                if (endAngle - startAngle >= 359.9) {
                    endAngle = startAngle + 359.99;
                }
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

            function drawCategoryPie(animate = false) {
                const targetPercentages = calculatePercentages();

                if (animate) {
                    // Animation Logic
                    const startPercentages = svg._lastPercentages || {};
                    // If no last percentages (first draw), use current target as start to avoid weirdness, or just skip animation.
                    // But if we want initial draw animation, we start from 0.
                    // For now, let's assume 'expanding' means from previous state.

                    // Cancel any previous animation
                    if (svg._animFrame) cancelAnimationFrame(svg._animFrame);

                    const duration = 600; // ms
                    const startTime = performance.now();

                    // Identify keys to animate
                    const allKeys = new Set([...Object.keys(startPercentages), ...Object.keys(targetPercentages)]);

                    function animateFrame(now) {
                        const elapsed = now - startTime;
                        const progress = Math.min(elapsed / duration, 1);

                        // Easing function (easeOutCubic)
                        const ease = 1 - Math.pow(1 - progress, 3);

                        const currentFramePercentages = {};

                        for (let k of allKeys) {
                            const s = startPercentages[k] || 0;
                            const t = targetPercentages[k] || 0;
                            currentFramePercentages[k] = s + (t - s) * ease;
                        }

                        renderPie(currentFramePercentages);

                        if (progress < 1) {
                            svg._animFrame = requestAnimationFrame(animateFrame);
                        } else {
                            // Final frame
                            svg._lastPercentages = targetPercentages;
                            renderPie(targetPercentages);
                        }
                    }

                    svg._animFrame = requestAnimationFrame(animateFrame);

                } else {
                    // No animation, just draw
                    svg._lastPercentages = targetPercentages;
                    renderPie(targetPercentages);
                }
            }

            function renderPie(percentages) {
                // Get ID for unique gradient names
                const isModal = svg.id.startsWith('modal-');
                const nameFromId = svg.id.replace(isModal ? 'modal-nested-donut-' : 'nested-donut-', '');

                // HIDE SKELETON (Fade out opacity)
                const skeletonId = 'skeleton-html-' + nameFromId;
                const skeleton = document.getElementById(skeletonId);

                if (skeleton) {
                    console.log('Found skeleton:', skeletonId, '- Hiding now.');
                    // Force fade out directly via style
                    skeleton.style.transition = 'opacity 0.5s ease-out';
                    skeleton.style.opacity = '0';
                    skeleton.style.zIndex = '-1'; // Send to back immediately to prevent click blocking

                    // Remove from DOM after transition
                    setTimeout(() => {
                        if (skeleton.parentNode) {
                            skeleton.parentNode.removeChild(skeleton);
                        }
                    }, 600);
                } else {
                    console.log('Skeleton NOT found:', skeletonId);
                }

                innerRing.innerHTML = '';

                // --- 1. DEFINITIONS (Gradients & Filters) ---
                const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');

                // Drop Shadow Filter
                const filter = document.createElementNS('http://www.w3.org/2000/svg', 'filter');
                filter.setAttribute('id', 'premiumShadow');
                filter.innerHTML = `
                    <feGaussianBlur in="SourceAlpha" stdDeviation="3" result="blur"/>
                    <feOffset in="blur" dx="0" dy="2" result="offsetBlur"/>
                    <feComponentTransfer>
                        <feFuncA type="linear" slope="0.3"/> 
                    </feComponentTransfer>
                    <feMerge>
                        <feMergeNode/>
                        <feMergeNode in="SourceGraphic"/>
                    </feMerge>
                `;
                defs.appendChild(filter);

                // Gradients for each category
                const gradientConfigs = {
                    'การงาน': ['#90CAF9', '#42A5F5', '0'],     // Blue
                    'การเงิน': ['#FFCC80', '#FFA726', '-45'], // Gold/Orange (More Premium)
                    'ความรัก': ['#F48FB1', '#EC407A', '45'],  // Pink
                    'สุขภาพ': ['#80CBC4', '#26A69A', '90'],    // Teal
                    'N/A': ['#F5F5F5', '#E0E0E0', '0']     // Grey
                };

                for (const [cat, colors] of Object.entries(gradientConfigs)) {
                    // Unique ID for each gradient based on Chart ID + Category
                    const gradId = 'grad-' + nameFromId + '-' + cat;
                    const grad = document.createElementNS('http://www.w3.org/2000/svg', 'linearGradient');
                    grad.setAttribute('id', gradId);
                    // Rotate gradient for dynamic look
                    grad.setAttribute('gradientTransform', `rotate(${colors[2]})`);

                    const stop1 = document.createElementNS('http://www.w3.org/2000/svg', 'stop');
                    stop1.setAttribute('offset', '0%');
                    stop1.setAttribute('stop-color', colors[0]);

                    const stop2 = document.createElementNS('http://www.w3.org/2000/svg', 'stop');
                    stop2.setAttribute('offset', '100%');
                    stop2.setAttribute('stop-color', colors[1]);

                    grad.appendChild(stop1);
                    grad.appendChild(stop2);
                    defs.appendChild(grad);
                }
                // GOLD GRADIENT for Score
                const goldGrad = document.createElementNS('http://www.w3.org/2000/svg', 'linearGradient');
                goldGrad.setAttribute('id', 'grad-' + nameFromId + '-gold');
                goldGrad.setAttribute('x1', '0%');
                goldGrad.setAttribute('y1', '0%');
                goldGrad.setAttribute('x2', '100%');
                goldGrad.setAttribute('y2', '100%');
                goldGrad.innerHTML = `
                    <stop offset="0%" style="stop-color:#D97706;stop-opacity:1" />
                    <stop offset="50%" style="stop-color:#FFD700;stop-opacity:1" />
                    <stop offset="100%" style="stop-color:#B45309;stop-opacity:1" />
                `;
                defs.appendChild(goldGrad);

                innerRing.appendChild(defs);

                // --- 2. BACKGROUND RING (Track) ---
                // Outer Radius ~98, StrokeWidth ~30 -> Center Radius ~83
                const radius = 83;
                const strokeWidth = 32;
                const circumference = 2 * Math.PI * radius;

                const bgCircle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
                bgCircle.setAttribute('cx', '100');
                bgCircle.setAttribute('cy', '100');
                bgCircle.setAttribute('r', radius);
                bgCircle.setAttribute('fill', 'none');
                bgCircle.setAttribute('stroke', '#F1F5F9');
                bgCircle.setAttribute('stroke-width', strokeWidth);
                bgCircle.setAttribute('stroke-linecap', 'round'); // Round ends for track too
                innerRing.appendChild(bgCircle);

                let currentOffset = 0; // Dashoffset starts at 0 (top-right usually, but we rotate)

                // SVG circles start at 3 o'clock. We want -90deg (12 o'clock).
                // But dasharray works by length.

                let accumulatedPct = 0;

                // Draw segments using STROKE-DASHARRAY
                // We need to render them as separate circles overlapping, 
                // but rotated properly.

                for (const [cat, pct] of Object.entries(percentages)) {
                    if (cat !== 'N/A' && pct > 0) {
                        const gradUrl = `url(#grad-${nameFromId}-${cat})`; // Use local gradient

                        // Calculate arc length
                        const arcLength = (pct / 100) * circumference;

                        // NO GAP for seamless look, but subtracting a TINY bit allows the background (white) to peek through
                        // acting as a separator line.
                        const drawLength = Math.max(0, arcLength - 1.5); // 1.5px gap

                        // Create circle for this segment
                        const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
                        circle.setAttribute('cx', '100');
                        circle.setAttribute('cy', '100');
                        circle.setAttribute('r', radius);
                        circle.setAttribute('fill', 'none');
                        circle.setAttribute('stroke', gradUrl);
                        circle.setAttribute('stroke-width', strokeWidth);
                        // Default linecap is butt (straight), creating seamless look

                        // Dash Array: [Length of Arc, Rest of Circle]
                        circle.setAttribute('stroke-dasharray', `${drawLength} ${circumference}`);

                        // Dash Offset: Where to start drawing.
                        // SVG draws counter-clockwise from 3 o'clock? No, usually clockwise if we manage it right.
                        // Actually standard SVG circle with positive dasharray draws clockwise? 
                        // Wait, standard is: Start at 3 o'clock, go clockwise.
                        // We want to start at 12 o'clock (-90deg).

                        // Rotate the whole circle to the starting position of this segment
                        // Start Angle = -90 + (accumulatedPct / 100 * 360)
                        const startAngle = -90 + (accumulatedPct / 100) * 360;
                        circle.setAttribute('transform', `rotate(${startAngle} 100 100)`);

                        circle.setAttribute('class', 'donut-segment');
                        circle.setAttribute('style', 'cursor: pointer; transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);');

                        // Interaction
                        circle.addEventListener('mouseenter', function () {
                            this.setAttribute('stroke-width', strokeWidth + 4); // Thicker on hover
                            this.style.filter = 'brightness(1.1) drop-shadow(0 4px 6px rgba(0,0,0,0.15))';
                        });
                        circle.addEventListener('mouseleave', function () {
                            this.setAttribute('stroke-width', strokeWidth);
                            this.style.filter = '';
                        });

                        const titleElem = document.createElementNS('http://www.w3.org/2000/svg', 'title');
                        titleElem.textContent = `${cat}: ${Math.round(pct)}%`;
                        circle.appendChild(titleElem);

                        innerRing.appendChild(circle);

                        // Percent Label
                        if (pct >= 8) {
                            // Calculate position for text
                            // Angle is middle of this segment
                            const segmentMiddleAngle = -90 + ((accumulatedPct + pct / 2) / 100 * 360);
                            const midRad = (segmentMiddleAngle * Math.PI) / 180;

                            // Radius for text is same as circle radius (centered in stroke)
                            const textRadius = radius;

                            const tx = 100 + textRadius * Math.cos(midRad);
                            const ty = 100 + textRadius * Math.sin(midRad);

                            const textElem = document.createElementNS('http://www.w3.org/2000/svg', 'text');
                            textElem.setAttribute('x', tx);
                            textElem.setAttribute('y', ty);
                            textElem.setAttribute('text-anchor', 'middle');
                            textElem.setAttribute('dominant-baseline', 'middle');
                            textElem.setAttribute('fill', '#fff');
                            textElem.setAttribute('font-size', '14px');
                            textElem.setAttribute('font-weight', '900');
                            textElem.setAttribute('style', 'pointer-events: none; text-shadow: 0px 2px 2px rgba(0,0,0,0.2); font-family: "Kanit", sans-serif;');
                            textElem.textContent = Math.round(pct) + '%';
                            innerRing.appendChild(textElem);
                        }

                        accumulatedPct += pct;
                    }
                }

                // Add Center "WoW" Element (Total Score or Icon) - Optional
                const totalScore = Object.entries(percentages)
                    .filter(([k]) => k !== 'N/A')
                    .reduce((acc, [, v]) => acc + v, 0);

                // --- 2. CENTER PIECE (White Circle + Shadow + Text) ---
                const centerGroup = document.createElementNS('http://www.w3.org/2000/svg', 'g');

                // White background circle behind text
                const centerCircle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
                centerCircle.setAttribute('cx', '100');
                centerCircle.setAttribute('cy', '100');
                // Let's make center circle slightly smaller than that
                centerCircle.setAttribute('r', '58');
                centerCircle.setAttribute('fill', 'white');
                centerCircle.setAttribute('filter', 'url(#premiumShadow)');
                centerGroup.appendChild(centerCircle);

                // Score Text
                const scoreText = document.createElementNS('http://www.w3.org/2000/svg', 'text');
                scoreText.setAttribute('x', '100');
                scoreText.setAttribute('y', '90'); // Moved up slightly
                scoreText.setAttribute('text-anchor', 'middle');
                scoreText.setAttribute('font-size', '12px');
                scoreText.setAttribute('fill', '#64748B');
                scoreText.setAttribute('font-family', 'Kanit, sans-serif');
                scoreText.textContent = 'คะแนนรวม';
                centerGroup.appendChild(scoreText);

                const scoreVal = document.createElementNS('http://www.w3.org/2000/svg', 'text');
                scoreVal.setAttribute('x', '100');
                scoreVal.setAttribute('y', '120'); // Moved down slightly
                scoreVal.setAttribute('text-anchor', 'middle');
                scoreVal.setAttribute('font-size', '32px'); // Bigger
                scoreVal.setAttribute('font-weight', 'bold');

                // Color: GOLDEN AURA (Use the gradient we just made)
                const scoreColor = 'url(#grad-' + nameFromId + '-gold)';
                scoreVal.setAttribute('fill', scoreColor);

                // Add a drop shadow to the text itself for "Aura" effect
                // We can reuse premiumShadow or create a specific text shadow
                scoreVal.setAttribute('filter', 'url(#premiumShadow)');
                scoreVal.setAttribute('font-family', 'Kanit, sans-serif');
                scoreVal.textContent = Math.round(totalScore) + '%';
                centerGroup.appendChild(scoreVal);

                innerRing.appendChild(centerGroup);

                // --- SYNC LEGEND & TEXTS (Keep existing logic mostly, but refined) ---
                // variables isModal and nameFromId are already defined at the top

                ['สุขภาพ', 'การงาน', 'การเงิน', 'ความรัก'].forEach(cat => {
                    let pct = percentages[cat];
                    if (pct === undefined) return;

                    const targetTextId = isModal ? ('modal-good-score-container-' + nameFromId + '-' + cat) : ('good-score-container-' + nameFromId + '-' + cat);
                    const targetEl = document.getElementById(targetTextId);

                    if (targetEl) {
                        const luckyList = JSON.parse(svg.dataset.luckyCategories || '[]');
                        const isLucky = luckyList.includes(cat);

                        if (isLucky) {
                            // Gold Badge with Shimmer
                            targetEl.innerHTML = `
                                <div class="enhance-btn-shimmer" style="background: linear-gradient(135deg, #FFD700, #F59E0B); color: #fff; padding: 4px 12px; border-radius: 20px; font-weight: 800; font-size: 0.9rem; box-shadow: 0 4px 6px rgba(245, 158, 11, 0.4); display: inline-flex; align-items: center; justify-content: center; min-width: 80px;">
                                    ${Math.round(pct)}% <span style="font-size:1.2em; margin-left:4px;">✨</span>
                                </div>`;
                        } else {
                            // Standard Text
                            targetEl.innerHTML = `<span style="color: ${pct > 0 ? '#10B981' : '#CBD5E1'}; font-weight: 700; font-size: 1.1em;">${Math.round(pct)}%</span>`;
                        }
                    }
                });
            }

            svg.redraw = function () { drawCategoryPie(true); };
            svg.addLuckyCategory = function (category) {
                const lucky = JSON.parse(svg.dataset.luckyCategories || '[]');
                if (!lucky.includes(category)) {
                    lucky.push(category);
                    svg.dataset.luckyCategories = JSON.stringify(lucky);
                    drawCategoryPie(true);
                    console.log('[Category Pie] Added lucky category:', category);
                }
            };

            // Initial Draw
            drawCategoryPie();
            console.log('[Nested Donut] Successfully initialized:', id);

        } catch (error) {
            console.error('[Category Pie] Error:', error);
        }
    }

    // Start trying after DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', tryInit);
    } else {
        // DOM already loaded, start immediately
        setTimeout(tryInit, 0);
    }
};
