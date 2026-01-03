package admin

import (
	"context"
	"fmt"
	"io"
	"numberniceic/internal/core/domain"
	"strings"

	"github.com/a-h/templ"
)

// AuspiciousNumbers returns a templ component (manually implemented)
func AuspiciousNumbers(data domain.PagedPhoneNumberAnalysis) templ.Component {
	return templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
		// Custom Styles for Premium Feel (Vanilla CSS - No Tailwind)
		styles := `<style>
			.auspicious-page {
				padding: 2rem;
				background-color: #f8f9fa;
				min-height: 100vh;
				font-family: 'Sarabun', sans-serif;
			}
			.content-wrapper {
				max-width: 1280px;
				margin: 0 auto;
			}
			.header-section {
				display: flex;
				justify-content: space-between;
				align-items: center;
				margin-bottom: 2rem;
			}
			.header-title h1 {
				font-size: 1.875rem;
				font-weight: 800;
				color: #111827;
				margin: 0;
				font-family: 'Kanit', sans-serif;
			}
			.header-title p {
				color: #6b7280;
				margin-top: 0.25rem;
			}
			.total-badge {
				background-color: white;
				padding: 0.5rem 1rem;
				border-radius: 9999px;
				box-shadow: 0 1px 2px rgba(0,0,0,0.05);
				border: 1px solid #f3f4f6;
				display: flex;
				align-items: center;
				gap: 0.5rem;
				font-size: 0.875rem;
				font-weight: 700;
				color: #374151;
			}
			.pulse-dot {
				width: 8px;
				height: 8px;
				background-color: #10b981;
				border-radius: 50%;
				animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
			}
			@keyframes pulse {
				0%, 100% { opacity: 1; }
				50% { opacity: .5; }
			}
			.table-card {
				background-color: white;
				border-radius: 1rem;
				box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
				overflow: hidden;
				border: 1px solid #f3f4f6;
			}
			.scroll-container {
				overflow-x: auto;
			}
			.premium-table {
				width: 100%;
				border-collapse: collapse;
			}
			.premium-table th {
				background: linear-gradient(to bottom, #f9fafb, #f3f4f6);
				color: #4b5563;
				font-family: 'Kanit', sans-serif;
				font-size: 0.75rem;
				font-weight: 700;
				text-transform: uppercase;
				letter-spacing: 0.05em;
				padding: 1rem;
				border-bottom: 2px solid #e5e7eb;
				text-align: left;
			}
			.premium-table th.text-center { text-align: center; }
			.premium-table th.text-right { text-align: right; }
			.number-row {
				transition: all 0.2s ease;
				border-bottom: 1px solid #f3f4f6;
			}
			.number-row:hover {
				background-color: #fcfaff;
				transform: scale(1.002);
			}
			.number-row td {
				padding: 1.5rem 1rem;
				vertical-align: middle;
			}
			.pos-cell { color: #9ca3af; font-family: monospace; font-size: 0.75rem; text-align: center; }
			.phone-cell .phone-num { font-size: 1.5rem; font-weight: 700; color: #111827; letter-spacing: 0.05em; line-height: 1; }
			.phone-cell .phone-group { font-size: 11px; color: #9ca3af; margin-top: 4px; }
			.sum-circle {
				width: 3rem;
				height: 3rem;
				border-radius: 50%;
				display: flex;
				align-items: center;
				justify-content: center;
				color: white;
				font-size: 1.125rem;
				font-weight: 700;
				margin: 0 auto;
				box-shadow: inset 0 2px 4px rgba(0,0,0,0.1), 0 4px 10px rgba(0,0,0,0.1);
				border: 2px solid white;
			}
			.pairs-container {
				display: flex;
				margin-left: 0.5rem;
			}
			.pair-circle {
				width: 2.25rem;
				height: 2.25rem;
				border-radius: 50%;
				display: flex;
				align-items: center;
				justify-content: center;
				color: white;
				font-size: 11px;
				font-weight: 700;
				border: 2px solid white;
				margin-left: -0.5rem;
				box-shadow: 0 1px 2px rgba(0,0,0,0.1);
				transition: transform 0.2s;
				cursor: help;
			}
			.pair-circle:hover {
				transform: translateY(-3px);
				z-index: 10;
			}
			.score-badge {
				background-color: #fffbeb;
				color: #b45309;
				padding: 0.25rem 0.75rem;
				border-radius: 0.5rem;
				font-weight: 700;
				font-size: 0.875rem;
				border: 1px solid #fef3c7;
				display: inline-block;
			}
			.price-text { font-size: 1.125rem; font-weight: 800; color: #111827; text-align: right; }
			.status-pill {
				padding: 0.35rem 0.85rem;
				border-radius: 9999px;
				font-size: 10px;
				font-weight: 700;
				text-transform: uppercase;
				letter-spacing: 0.1em;
				display: inline-block;
			}
			.status-available { background-color: #dcfce7; color: #15803d; }
			.status-sold { background-color: #f3f4f6; color: #6b7280; }
			
			/* Pagination */
			.pag-nav {
				display: flex;
				justify-content: center;
				align-items: center;
				gap: 0.5rem;
				margin-top: 2.5rem;
				padding-bottom: 2rem;
			}
			.pag-link {
				display: flex;
				align-items: center;
				justify-content: center;
				width: 40px;
				height: 40px;
				background-color: white;
				border: 1px solid #e5e7eb;
				border-radius: 12px;
				color: #4b5563;
				text-decoration: none !important;
				font-weight: 500;
				transition: all 0.2s;
				box-shadow: 0 1px 2px rgba(0,0,0,0.05);
			}
			.pag-link:hover {
				border-color: #FDB931;
				color: #FDB931;
				transform: translateY(-2px);
			}
			.pag-link.active {
				background: linear-gradient(135deg, #FFD700 0%, #FDB931 100%);
				color: #4a3b00 !important;
				border-color: transparent;
				font-weight: 700;
				box-shadow: 0 4px 12px rgba(253, 185, 49, 0.3);
			}
		</style>`

		// Start HTML
		_, err := io.WriteString(w, styles+`<div class="auspicious-page">
			<div class="content-wrapper">
				<div class="header-section">
					<div class="header-title">
						<h1>เบอร์มงคล</h1>
						<p>วิเคราะห์และคัดกรองเบอร์โทรศัพท์ตามหลักเลขศาสตร์</p>
					</div>
					<div class="total-badge">
						<div class="pulse-dot"></div>
						<span>ทั้งหมด `+fmt.Sprintf("%d", data.TotalCount)+` รายการ</span>
					</div>
				</div>
				
				<div class="table-card">
					<div class="scroll-container">
						<table class="premium-table">
							<thead>
								<tr>
									<th class="text-center">ลำดับ</th>
									<th>หมายเลขโทรศัพท์</th>
									<th class="text-center">ผลรวม</th>
									<th>คู่หลัก (แกนกลาง)</th>
									<th>คู่แฝง (พลังแฝง)</th>
									<th class="text-center">คะแนน</th>
									<th class="text-right">ราคา (บาท)</th>
									<th class="text-center">สถานะ</th>
								</tr>
							</thead>
							<tbody>`)
		if err != nil {
			return err
		}

		for _, item := range data.Items {
			// Helper to generate circles
			renderCircles := func(pairs []domain.PhoneNumberPairMeaning) string {
				html := `<div class="pairs-container">`
				for _, p := range pairs {
					color := p.Meaning.Color
					if color == "" {
						color = "#9E9E9E"
					}
					html += fmt.Sprintf(`<div class="pair-circle" style="background-color: %s;" title="%s: %s (%d)">%s</div>`,
						color, p.Pair, p.Meaning.MiracleDetail, p.Meaning.PairPoint, p.Pair)
				}
				html += `</div>`
				return html
			}

			primaryHtml := renderCircles(item.PrimaryPairs)
			secondaryHtml := renderCircles(item.SecondaryPairs)

			sumColor := item.SumMeaning.Color
			if sumColor == "" {
				sumColor = "#9E9E9E"
			}
			sumHtml := fmt.Sprintf(`<div class="sum-circle" style="background-color: %s; background-image: linear-gradient(135deg, rgba(255,255,255,0.2) 0%%, rgba(0,0,0,0.1) 100%%);" title="%s: %s">%s</div>`,
				sumColor, item.SumMeaning.PairNumber, item.SumMeaning.MiracleDetail, item.PhoneNumber.PNumberSum)

			statusClass := "status-available"
			if strings.Contains(strings.ToLower(item.PhoneNumber.SellStatus), "sold") {
				statusClass = "status-sold"
			}

			row := fmt.Sprintf(`<tr class="number-row">
				<td class="pos-cell">%d</td>
				<td class="phone-cell">
					<div class="phone-num">%s</div>
					<div class="phone-group">%s</div>
				</td>
				<td style="text-align: center;">%s</td>
				<td style="padding-left: 0;">%s</td>
				<td style="padding-left: 0;">%s</td>
				<td style="text-align: center;">
					<span class="score-badge">%d</span>
				</td>
				<td class="price-text">%d</td>
				<td style="text-align: center;">
					<span class="status-pill %s">%s</span>
				</td>
			</tr>`,
				item.PhoneNumber.PNumberPosition,
				item.PhoneNumber.PNumberNum,
				item.PhoneNumber.PhoneGroup,
				sumHtml,
				primaryHtml,
				secondaryHtml,
				item.TotalScore,
				item.PhoneNumber.PNumberPrice,
				statusClass,
				item.PhoneNumber.SellStatus)

			_, err = io.WriteString(w, row)
			if err != nil {
				return err
			}
		}

		_, err = io.WriteString(w, `</tbody></table></div></div>`)
		if err != nil {
			return err
		}

		// Pagination Controls
		if data.TotalPages > 1 {
			paginationHtml := `<div class="pag-nav">`

			// Previous Button
			if data.CurrentPage > 1 {
				paginationHtml += fmt.Sprintf(`<a href="?page=%d" class="pag-link">&larr;</a>`, data.CurrentPage-1)
			}

			// Page Numbers
			startPage := data.CurrentPage - 2
			if startPage < 1 {
				startPage = 1
			}
			endPage := startPage + 4
			if endPage > data.TotalPages {
				endPage = data.TotalPages
			}

			for i := startPage; i <= endPage; i++ {
				activeClass := ""
				if i == data.CurrentPage {
					activeClass = "active"
				}
				paginationHtml += fmt.Sprintf(`<a href="?page=%d" class="pag-link %s">%d</a>`, i, activeClass, i)
			}

			// Next Button
			if data.CurrentPage < data.TotalPages {
				paginationHtml += fmt.Sprintf(`<a href="?page=%d" class="pag-link">&rarr;</a>`, data.CurrentPage+1)
			}

			paginationHtml += `</div>`
			_, err = io.WriteString(w, paginationHtml)
		}

		_, err = io.WriteString(w, `</div></div>`)
		return err
	})
}
