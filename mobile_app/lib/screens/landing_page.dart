import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../utils/custom_toast.dart';
import '../models/article.dart';
import '../services/api_service.dart';
import 'article_detail_page.dart';
import 'articles_page.dart';
import 'dashboard_page.dart';
import 'analyzer_page.dart';
import 'login_page.dart';
import 'register_page.dart';
import '../widgets/shared_footer.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late Future<List<Article>> _articlesFuture;
  late Future<bool> _isBuddhistDayFuture;
  late Future<Map<String, dynamic>> _userInfoFuture;

  @override
  void initState() {
    super.initState();
    _articlesFuture = ApiService.getArticles();
    _isBuddhistDayFuture = ApiService.isBuddhistDayToday();
    _userInfoFuture = AuthService.getUserInfo();
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
        backgroundColor: const Color(0xFF333333),
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'ชื่อดี.com',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Kanit',
            fontSize: 22,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF444444),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Buddhist Day Badge
                FutureBuilder<bool>(
                  future: _isBuddhistDayFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data == true) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_vintage_rounded, size: 18, color: Color(0xFFFFD700)),
                            const SizedBox(width: 6),
                            Text(
                              'วันนี้วันพระ', 
                              style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFFD700)),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
                
                
                // Premium Gradient Action Button
                InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyzerPage()));
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF667EEA).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.analytics_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'วิเคราะห์ชื่อ',
                          style: GoogleFonts.kanit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FutureBuilder<Map<String, dynamic>>(
            future: _userInfoFuture,
            builder: (context, snapshot) {
              final userInfo = snapshot.data;
              final isLoggedIn = userInfo != null && userInfo['username'] != null;

              if (isLoggedIn) {
                return TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DashboardPage())),
                  icon: const Icon(Icons.dashboard_outlined, color: Colors.white, size: 20),
                  label: Text('แดชบอร์ด', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold)),
                );
              } else {
                return TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage())),
                  icon: const Icon(Icons.login_outlined, color: Colors.white, size: 20),
                  label: Text('เข้าสู่ระบบ', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold)),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _userInfoFuture,
          builder: (context, snapshot) {
             final userInfo = snapshot.data;
             final isLoggedIn = userInfo != null && userInfo['username'] != null;
             
             return ListView(
               padding: EdgeInsets.zero,
               children: [
                 DrawerHeader(
                   decoration: const BoxDecoration(
                     gradient: LinearGradient(
                       colors: [Color(0xFF00b09b), Color(0xFF96c93d)],
                       begin: Alignment.topLeft,
                       end: Alignment.bottomRight,
                     ),
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     mainAxisAlignment: MainAxisAlignment.end,
                     children: [
                       const CircleAvatar(
                         radius: 30,
                         backgroundColor: Colors.white,
                         child: Icon(Icons.person, size: 40, color: Colors.teal),
                       ),
                       const SizedBox(height: 10),
                       Text(
                         isLoggedIn ? 'สวัสดี, ${userInfo['username']}' : 'ยินดีต้อนรับ',
                         style: GoogleFonts.kanit(
                           color: Colors.white,
                           fontSize: 20,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ],
                   ),
                 ),
                 
                 // Menu Items logic
                 ListTile(
                   leading: const Icon(Icons.home),
                   title: Text('หน้าแรก', style: GoogleFonts.kanit()),
                   onTap: () => Navigator.pop(context),
                 ),
                 ListTile(
                   leading: const Icon(Icons.article),
                   title: Text('บทความ', style: GoogleFonts.kanit()),
                   onTap: () {
                     Navigator.pop(context);
                     Navigator.push(
                       context,
                       MaterialPageRoute(builder: (context) => const ArticlesPage()),
                     );
                   },
                 ),
                 const Divider(),

                 if (isLoggedIn) ...[
                   // Logged In Menus
                   ListTile(
                      leading: const Icon(Icons.dashboard_rounded, color: Colors.teal),
                      title: Text('แดชบอร์ด', style: GoogleFonts.kanit(color: Colors.teal, fontWeight: FontWeight.bold)),
                      onTap: () {
                         Navigator.pop(context); // Close drawer
                         Navigator.push(
                           context, 
                           MaterialPageRoute(builder: (context) => const DashboardPage())
                         );
                      },
                    ),
                   const Divider(),
                   ListTile(
                     leading: const Icon(Icons.logout, color: Colors.deepOrange),
                     title: Text('ออกจากระบบ', style: GoogleFonts.kanit(color: Colors.deepOrange)),
                     onTap: () async {
                       await AuthService.logout();
                       if (context.mounted) {
                          Navigator.pop(context);
                          CustomToast.show(context, 'ออกจากระบบเรียบร้อยแล้ว');
                          setState(() {}); 
                       }
                     },
                   ),
                 ] else ...[
                   // Guest Menus
                   ListTile(
                     leading: const Icon(Icons.login),
                     title: Text('เข้าสู่ระบบ', style: GoogleFonts.kanit()),
                     onTap: () {
                       Navigator.pop(context);
                       Navigator.push(
                         context,
                         MaterialPageRoute(builder: (context) => const LoginPage()),
                       ).then((_) => setState(() {}));
                     },
                   ),
                   ListTile(
                     leading: const Icon(Icons.person_add),
                     title: Text('สมัครสมาชิก', style: GoogleFonts.kanit()),
                     onTap: () {
                       Navigator.pop(context);
                       Navigator.push(
                         context,
                         MaterialPageRoute(builder: (context) => const RegisterPage()),
                       );
                     },
                   ),
                 ],
               ],
             );
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SharedFooter(),
            ],
          ),
        ),
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
                        height: 150, 
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
                                ...subArticles.sublist(3, subArticles.length > 5 ? 5 : subArticles.length).map((a) => 
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
                                           fontSize: 14,
                                           fontWeight: FontWeight.w300,
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
                                        'ดูบทความทั้งหมด',
                                        style: GoogleFonts.kanit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
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
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.kanit(
                      color: Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.w300, 
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.kanit(
                      color: const Color(0xFF555555),
                      fontSize: 16,
                      height: 1.4,
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
        height: 150,
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
              fontWeight: FontWeight.w300,
              fontSize: 16,
              height: 1.2,
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

