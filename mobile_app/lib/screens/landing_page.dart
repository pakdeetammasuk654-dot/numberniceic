import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/logo_widget.dart';
import '../services/auth_service.dart';
import '../utils/custom_toast.dart';
import '../models/article.dart';
import '../services/api_service.dart';
import '../widgets/welcome_dialog.dart';
import '../widgets/buddhist_day_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'article_detail_page.dart';
import 'articles_page.dart';
import 'dashboard_page.dart';
import '../services/notification_service.dart';
import 'analyzer_page.dart';
import 'shipping_address_page.dart';
import 'notification_list_page.dart';
import 'login_page.dart';
import 'main_tab_page.dart';
import 'number_analysis_page.dart';
import '../widgets/shared_footer.dart';
import '../widgets/adaptive_footer_scroll_view.dart';
import '../widgets/notification_bell.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late Future<List<Article>> _articlesFuture;
  late Future<bool> _isBuddhistDayFuture;
  late Future<Map<String, dynamic>> _userInfoFuture;
  bool _hasUnreadNotification = false;
  Map<String, dynamic>? _pendingConfig;
  // New state
  int _unreadCount = 0;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _articlesFuture = ApiService.getArticles();
    _isBuddhistDayFuture = NotificationService().checkIsBuddhistDayToday();
    _userInfoFuture = AuthService.getUserInfo();
    // Check notification on init (deferred)
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNotification());
  }

  Future<void> _refresh() async {
    setState(() {
      _articlesFuture = ApiService.getArticles();
    });
    // Check notification after refresh
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNotification());
  }



  Future<void> _checkNotification() async {
    final token = await AuthService.getToken();
    _isLoggedIn = token != null;
    
    if (_isLoggedIn) {
        // Logged In: Check individual notifications AND System Status (Missing Address)
        try {
            // 1. Check Unread Messages
            final count = await ApiService.getUnreadNotificationCount();
            
            if (mounted) {
                setState(() {
                    _unreadCount = count;
                    // Light up if has unread messages
                    _hasUnreadNotification = count > 0;
                });
            }
        } catch (_) {}
    } else {
        // Guest: Check Global Welcome Message
        final prefs = await SharedPreferences.getInstance();
        try {
            final apiConfig = await ApiService.getWelcomeMessage();
            if (apiConfig != null && (apiConfig['is_active'] ?? true)) {
                final int version = apiConfig['version'] ?? 1;
                final int lastShownVersion = prefs.getInt('welcome_msg_version') ?? 0;
                
                if (version > lastShownVersion) {
                    setState(() {
                        _hasUnreadNotification = true;
                        _pendingConfig = apiConfig;
                    });
                } else {
                    setState(() {
                        _hasUnreadNotification = false;
                        _pendingConfig = apiConfig;
                    });
                }
            }
        } catch (_) {}
    }
  }
  
  void _handleNotificationTap() {
    if (_isLoggedIn) {
      // Normal Navigation
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NotificationListPage()),
      ).then((_) {
        _checkNotification();
      });
    } else {
      _showWelcomeDialog();
    }
  }

  void _showWelcomeDialog() {
     if (_pendingConfig != null) {
        String body = (_pendingConfig!['body'] ?? '').replaceAll('\\n', '\n');
        WelcomeDialog.show(
            context: context,
            title: _pendingConfig!['title'] ?? 'ประกาศ',
            body: body,
            version: _pendingConfig!['version'] ?? 1,
            onDismiss: () {
                setState(() {
                    _hasUnreadNotification = false;
                });
                _checkNotification(); 
            }
        );
     } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่มีการแจ้งเตือนใหม่')),
        );
     }
  }
  


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AdaptiveFooterScrollView(
        onRefresh: _refresh,
        children: [
          FutureBuilder<List<Article>>(
            future: _articlesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasError) {
                return Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Error loading articles.\nMake sure server is running.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: Text('No articles found.')),
                );
              }

              final articles = snapshot.data!;
              return _buildHeroSection(context, articles);
            },
          ),
          
          _buildTrustStatsSection(context),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, List<Article> articles) {
    if (articles.isEmpty) return const SizedBox.shrink();

    final mainArticle = articles[0];
    final subArticles = articles.length > 1 ? articles.sublist(1) : <Article>[];

    return Column(
      children: [
        _buildMainHero(context, mainArticle),
        if (subArticles.isNotEmpty)
          Column(
            children: [
              Row(
                children: [
                   if (subArticles.isNotEmpty) Expanded(child: _buildSubHeroItem(context, subArticles[0])),
                   if (subArticles.length > 1) Expanded(child: _buildSubHeroItem(context, subArticles[1])),
                ],
              ),
              Row(
                children: [
                   if (subArticles.length > 2) Expanded(child: _buildSubHeroItem(context, subArticles[2])),
                    Expanded(
                      child: Container(
                        height: 180, 
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ArticlesPage()),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (subArticles.length > 3)
                                ...subArticles.sublist(3, subArticles.length > 6 ? 6 : subArticles.length).map((a) => 
                                   Expanded(
                                     child: Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 16),
                                       decoration: BoxDecoration(
                                         border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                                       ),
                                       alignment: Alignment.centerLeft,
                                       child: Text(
                                         "• ${a.titleShort.isNotEmpty ? a.titleShort : a.title}",
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                         style: GoogleFonts.kanit(
                                           color: Colors.white,
                                           fontSize: 20,
                                           fontWeight: FontWeight.w400,
                                           height: 1.1,
                                         ),
                                       ),
                                     ),
                                   )
                                ),
                              // "See All" item
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'ดูทั้งหมด',
                                        style: GoogleFonts.kanit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMainHero(BuildContext context, Article article) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailPage(
              slug: article.slug,
              placeholderImage: article.imageUrl,
              placeholderTitle: article.title,
            ),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          SizedBox(
            height: 380,
            width: double.infinity,
            child: Image.network(
              article.imageUrl.startsWith('http') 
                ? article.imageUrl 
                : '${ApiService.baseUrl}${article.imageUrl}', 
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[300], child: const Icon(Icons.image, size: 50)),
            ),
          ),
          Container(
            height: 380,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.4),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 12, 
            left: 0,
            right: 24, 
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: const BoxDecoration(
                color: Color.fromRGBO(255, 255, 255, 0.9), 
                borderRadius: BorderRadius.zero,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    article.category.toUpperCase(),
                    style: GoogleFonts.kanit(
                      color: const Color(0xFFDC3545),
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      letterSpacing: 0.5,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.kanit(
                      color: Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.w300, 
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    article.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.kanit(
                      color: const Color(0xFF555555),
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeroItem(BuildContext context, Article article) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailPage(
              slug: article.slug,
              placeholderImage: article.imageUrl,
              placeholderTitle: article.title,
            ),
          ),
        );
      },
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
              article.imageUrl.startsWith('http') 
                ? article.imageUrl 
                : '${ApiService.baseUrl}${article.imageUrl}'
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
            ),
          ),
          padding: const EdgeInsets.all(16),
          alignment: Alignment.bottomCenter,
          child: Text(
            article.titleShort.isNotEmpty ? article.titleShort : article.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.kanit(
              color: Colors.white,
              fontWeight: FontWeight.w400,
              fontSize: 20,
              height: 1.1,
              shadows: [const Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustStatsSection(BuildContext context) {
    return Container(
      color: Colors.grey[50], 
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          _buildStatItem(
            context,
            icon: Icons.shield,
            iconColor: Colors.amber[700]!,
            bgIconColor: const Color(0xFFfffaf0),
            number: '300,000+',
            label: 'ชื่อคนไทยในระบบ',
          ),
          const SizedBox(height: 12),
          _buildStatItem(
            context,
            icon: Icons.check_circle,
            iconColor: Colors.blue[600]!,
            bgIconColor: const Color(0xFFebf8ff),
            number: '50,000+',
            label: 'การวิเคราะห์สำเร็จ',
          ),
          const SizedBox(height: 12),
          _buildStatItem(
            context,
            icon: Icons.circle,
            iconColor: Colors.green,
            bgIconColor: const Color(0xFFf0fff4),
            number: '24 คน',
            label: 'กำลังใช้งานออนไลน์',
            isLive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color bgIconColor,
    required String number,
    required String label,
    bool isLive = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgIconColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: isLive ? 12 : 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2d3748),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF718096),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

