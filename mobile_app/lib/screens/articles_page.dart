import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/article.dart';
import '../services/api_service.dart';
import 'article_detail_page.dart';
import '../widgets/shared_footer.dart';
import '../widgets/buddhist_day_badge.dart';

class ArticlesPage extends StatefulWidget {
  const ArticlesPage({super.key});

  @override
  State<ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends State<ArticlesPage> {
  late Future<List<Article>> _articlesFuture;

  @override
  void initState() {
    super.initState();
    _articlesFuture = ApiService.getArticles();
  }

  Future<void> _refresh() async {
    setState(() {
      _articlesFuture = ApiService.getArticles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'บทความทั้งหมด',
              style: GoogleFonts.kanit(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              )
            ),
            const BuddhistDayBadge(),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Article>>(
          future: _articlesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('ไม่พบบทความ'));
            }

            final articles = snapshot.data!;
            
            // Grid View Flush Layout
            // CustomScrollView to accommodate Footer
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, 
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 1,
                    mainAxisSpacing: 1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final article = articles[index];
                      return _buildArticleCard(context, article);
                    },
                    childCount: articles.length,
                  ),
                ),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      Spacer(),
                      SharedFooter(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildArticleCard(BuildContext context, Article article) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailPage(slug: article.slug),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          // No borderRadius
          image: DecorationImage(
            image: NetworkImage(
              article.imageUrl.startsWith('http') 
              ? article.imageUrl 
              : '${ApiService.baseUrl}${article.imageUrl}'
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            // Dark Gradient Overlay for text readability
            Container(
              decoration: BoxDecoration(
                // No borderRadius
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            // Text Content Overlay
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    article.category.toUpperCase(),
                    style: GoogleFonts.kanit(
                      fontSize: 10,
                      color: const Color(0xFFff6b6b), // Lighter red for visibility on dark
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.kanit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      color: Colors.white, // White text on dark
                      shadows: [
                        const Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                        )
                      ]
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
