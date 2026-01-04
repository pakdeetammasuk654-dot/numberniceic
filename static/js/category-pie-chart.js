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
        var container = document.getElementById('purchase-modal-target-number');
        if (container) {
            container.innerText = phoneNumber;
        }
        var input = document.getElementById('purchase-modal-number-input');
        if (input) input.value = phoneNumber;
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
    setTimeout(() => {
        try {
            console.log('[Nested Donut] Starting for ID:', id);

            var breakdown;
            try {
                breakdown = JSON.parse(atob(data));
            } catch (e) {
                console.error("Failed to parse base64 data", e);
                return;
            }

            const svg = document.getElementById(id);
            if (!svg) {
                console.error('[Nested Donut] SVG not found:', id);
                return;
            }

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
                innerRing.innerHTML = '';

                // Draw Full Circle Border (Background) to show full potential
                const fullCircle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
                fullCircle.setAttribute('cx', '100');
                fullCircle.setAttribute('cy', '100');
                fullCircle.setAttribute('r', '95');
                fullCircle.setAttribute('fill', 'none');
                fullCircle.setAttribute('stroke', '#e0e0e0');
                fullCircle.setAttribute('stroke-width', '1');
                fullCircle.setAttribute('stroke-dasharray', '4 4'); // Dashed to indicate "empty slots"
                innerRing.appendChild(fullCircle);

                let currentAngle = -90;
                const colorMap = { 'สุขภาพ': '#80CBC4', 'การงาน': '#90CAF9', 'การเงิน': '#FFCC80', 'ความรัก': '#F48FB1', 'N/A': '#ffffff00' };

                for (const [cat, pct] of Object.entries(percentages)) {
                    const angle = (pct / 100) * 360;

                    if (cat !== 'N/A') {
                        const color = colorMap[cat] || '#A0A0A0';
                        // Increased thickess to 95 (almost full 100 radius)
                        const path = createArcPath(100, 100, 0, 95, currentAngle, currentAngle + angle);

                        const pathElem = document.createElementNS('http://www.w3.org/2000/svg', 'path');
                        pathElem.setAttribute('d', path);
                        pathElem.setAttribute('fill', color);
                        pathElem.setAttribute('class', 'donut-segment category-segment');
                        pathElem.setAttribute('stroke', '#fff');
                        pathElem.setAttribute('stroke-width', '2');

                        const titleElem = document.createElementNS('http://www.w3.org/2000/svg', 'title');
                        titleElem.textContent = cat + ': ' + Math.round(pct) + '%';
                        pathElem.appendChild(titleElem);
                        innerRing.appendChild(pathElem);

                        if (pct >= 5) {
                            const labelRadius = 60; // Moved text outwards for better visibility
                            const midAngle = currentAngle + (angle / 2);
                            const midRad = (midAngle * Math.PI) / 180;
                            const tx = 100 + labelRadius * Math.cos(midRad);
                            const ty = 100 + labelRadius * Math.sin(midRad);

                            const textElem = document.createElementNS('http://www.w3.org/2000/svg', 'text');
                            textElem.setAttribute('x', tx);
                            textElem.setAttribute('y', ty); // Correct vertical alignment for middle
                            textElem.setAttribute('text-anchor', 'middle');
                            textElem.setAttribute('dominant-baseline', 'middle'); // Important for vertical centering
                            textElem.setAttribute('fill', '#fff'); // Always white for category pie
                            textElem.setAttribute('font-size', '12px');
                            textElem.setAttribute('font-weight', 'bold');
                            textElem.setAttribute('style', 'pointer-events: none; text-shadow: 0px 1px 2px rgba(0,0,0,0.5);');
                            // Use Math.round to ensure consistency with table
                            textElem.textContent = Math.round(pct) + '%';
                            innerRing.appendChild(textElem);
                        }
                    }
                    currentAngle += angle;
                }

                // --- NEW CODE: SYNC TABLE TEXT WITH CALCULATED PERCENTAGE ---
                // 'svg.id' is expected to be 'nested-donut-NAME' or 'modal-nested-donut-NAME'
                const isModal = svg.id.startsWith('modal-');
                const nameFromId = svg.id.replace(isModal ? 'modal-nested-donut-' : 'nested-donut-', '');

                ['สุขภาพ', 'การงาน', 'การเงิน', 'ความรัก'].forEach(cat => {
                    // Get the pct for this category from our just-calculated map (or 0 if missing)
                    let pct = percentages[cat];
                    if (pct === undefined) return; // Category might not exist in this rendering cycle if inactive, but usually we iterate all 4

                    const targetTextId = isModal ? ('modal-good-score-container-' + nameFromId + '-' + cat) : ('good-score-container-' + nameFromId + '-' + cat);
                    const targetEl = document.getElementById(targetTextId);

                    if (targetEl) {
                        const luckyList = JSON.parse(svg.dataset.luckyCategories || '[]');
                        const isLucky = luckyList.includes(cat);

                        if (isLucky) {
                            // 1. Golden Badge Style - Centered
                            targetEl.innerHTML = '<div style="background: linear-gradient(135deg, #FFD700, #F59E0B); color: #fff; padding: 4px 12px; border-radius: 20px; font-weight: 800; font-size: 0.9rem; box-shadow: 0 2px 4px rgba(245, 158, 11, 0.3); display: inline-flex; align-items: center; justify-content: center; min-width: 60px;">' +
                                Math.round(pct) + '% <svg style="width:12px;height:12px;margin-left:2px;" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M12 2L15 9L22 9L17 14L19 21L12 17L5 21L7 14L2 9L9 9L12 2Z" fill="white" stroke="none"/></svg></div>';
                            targetEl.style.textAlign = 'center';
                        } else {
                            // 2. Standard Green Text - Right Aligned
                            targetEl.innerHTML = '<span class="category-pct-display" data-category="' + cat + '" style="color: #2E7D32; font-weight: 700; font-size: 1.1em; display: flex; align-items: center; justify-content: flex-end; gap: 4px;">' +
                                '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="check-icon" style="display: none;"><polyline points="20 6 9 17 4 12"></polyline></svg>' +
                                '<span class="value-text">' + Math.round(pct) + '%</span></span>';
                            targetEl.style.textAlign = 'right';
                        }
                    }
                });

                // Update Total Score Display
                // Calculate total excluding N/A
                let totalScore = 0;
                for (let k in percentages) {
                    if (k !== 'N/A') totalScore += percentages[k];
                }

                const totalContainer = document.getElementById('total-score-' + nameFromId);
                if (totalContainer) {
                    const valSpan = totalContainer.querySelector('.score-value');
                    if (valSpan) {
                        // Add stars to total score if it's 100%
                        valSpan.textContent = Math.round(totalScore) + '%' + (totalScore >= 99.5 ? ' ✨' : '');
                    }
                }
                const modalTotalContainer = document.getElementById('modal-total-score-' + nameFromId);
                if (modalTotalContainer) {
                    const valSpan = modalTotalContainer.querySelector('.score-value');
                    if (valSpan) {
                        valSpan.textContent = Math.round(totalScore) + '%' + (totalScore >= 99.5 ? ' ✨' : '');
                    }
                }
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

        } catch (error) {
            console.error('[Category Pie] Error:', error);
        }
    }, 0);
};
