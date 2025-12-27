import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/article.dart';
import '../services/api_service.dart';
import '../widgets/shared_footer.dart';

class ArticleDetailPage extends StatefulWidget {
  final String slug;
  final String? placeholderImage;
  final String? placeholderTitle;

  const ArticleDetailPage({
    super.key, 
    required this.slug,
    this.placeholderImage,
    this.placeholderTitle,
  });

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  late Future<Article> _articleFuture;

  @override
  void initState() {
    super.initState();
    _articleFuture = ApiService.getArticleBySlug(widget.slug);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Article>(
        future: _articleFuture,
        builder: (context, snapshot) {
          // While loading, use placeholder or loading spinner
          if (snapshot.connectionState == ConnectionState.waiting) {
             return _buildLoadingState();
          } else if (snapshot.hasError) {
             return Scaffold(
               appBar: AppBar(title: const Text('Error')),
               body: Center(child: Text('Error: ${snapshot.error}')),
             );
          } else if (!snapshot.hasData) {
             return const Scaffold(body: Center(child: Text('Not Found')));
          }

          final article = snapshot.data!;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 2,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  article.category,
                  style: GoogleFonts.kanit(
                    color: Colors.black, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Section (Full Width, Aspect Ratio Preserved)
                    SizedBox(
                      width: double.infinity,
                      child: Image.network(
                        article.imageUrl.startsWith('http') 
                        ? article.imageUrl 
                        : '${ApiService.baseUrl}${article.imageUrl}',
                        fit: BoxFit.contain, // Ensure full image is visible
                        errorBuilder: (ctx, err, stack) => Container(
                          height: 200, 
                          color: Colors.grey[200], 
                          child: const Icon(Icons.broken_image)
                        ),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.title,
                            style: GoogleFonts.kanit(
                              fontSize: 24, 
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Published Date
                          if (article.publishedAt != null)
                             Text(
                               _formatThaiDate(article.publishedAt!),
                               style: GoogleFonts.kanit(
                                 fontSize: 14,
                                 color: Colors.grey[600],
                               ),
                             ),

                          const SizedBox(height: 12),
                          // Divider line
                          Container(
                            width: 40, 
                            height: 4, 
                            color: Colors.teal, 
                            margin: const EdgeInsets.only(bottom: 24)
                          ),
                          
                          // Content Section with HTML Rendering
                          HtmlWidget(
                            // Inject indentation manually for guaranteed rendering
                            article.content.replaceAll('<p>', '<p>&emsp;&emsp;'),
                            // Set base URL for relative images (like /static/...)
                            baseUrl: Uri.parse(ApiService.baseUrl),
                            textStyle: GoogleFonts.sarabun(
                              fontSize: 18,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                            // Optional configurations
                            renderMode: RenderMode.column,
                            onLoadingBuilder: (context, element, loadingProgress) 
                              => const Center(child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              )),
                          ),
                          
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SharedFooter()),
            ],
          );
        },
      ),
    );
  }

  String _formatThaiDate(DateTime date) {
    const months = [
      'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
      'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  Widget _buildLoadingState() {
     return Scaffold(
       appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
       body: const Center(child: CircularProgressIndicator()),
     );
  }
}
