import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'services/youtube_service.dart';

const Color kColorBg = Color(0xFFF9FAFB);
const Color kColorTextTitle = Color(0xFF1F2937);
const Color kColorTextSubtitle = Color(0xFF4B5563);
const Color kColorBtnPrimary = Color(0xFF2563EB);
const Color kColorCardBg = Colors.white;

class HealingScreen extends StatefulWidget {
  const HealingScreen({Key? key}) : super(key: key);

  @override
  State<HealingScreen> createState() => _HealingScreenState();
}

class _HealingScreenState extends State<HealingScreen> {
  int _selectedToggleIndex = 0; // 0: 전체, 1: 명상, 2: 수면, 3: ASMR
  final YoutubeService _youtube = YoutubeService();

  bool _loading = true;
  List<Map<String, String>> _videos = [];

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _loading = true);
    List<Map<String, String>> fetched = [];
    switch (_selectedToggleIndex) {
      case 0:
        fetched = await _youtube.fetchByKeyword('힐링 명상 음악');
        break;
      case 1:
        fetched = await _youtube.fetchByKeyword('명상 meditation mindfulness');
        break;
      case 2:
        fetched = await _youtube.fetchByKeyword('수면 음악 sleep relaxation');
        break;
      case 3:
        fetched = await _youtube.fetchByKeyword('ASMR 자연소리 힐링');
        break;
    }
    setState(() {
      _videos = fetched;
      _loading = false;
    });
  }

  void _onToggle(int index) {
    setState(() => _selectedToggleIndex = index);
    _loadVideos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '오늘의 힐링',
          style: GoogleFonts.roboto(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kColorBg,
        elevation: 0,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding:
        const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            _buildCategoryToggle(),
            const SizedBox(height: 24.0),
            if (_videos.isEmpty)
              const Text('불러올 영상이 없습니다.'),
            ..._videos.map((v) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildHealingCard(
                context: context,
                imageUrl: v['thumb'] ?? '',
                title: v['title'] ?? '',
                description: v['desc'] ?? '',
                videoId: v['id'] ?? '',
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryToggle() {
    const tabs = ['전체', '명상', '수면', 'ASMR'];
    return Container(
      height: 52.0,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _selectedToggleIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onToggle(i),
              child: Container(
                height: 36.0,
                decoration: BoxDecoration(
                  color: selected ? kColorBtnPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Center(
                  child: Text(
                    tabs[i],
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w500,
                      fontSize: 14.0,
                      color: selected ? Colors.white : kColorTextSubtitle,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHealingCard({
    required BuildContext context,
    required String imageUrl,
    required String title,
    required String description,
    required String videoId,
  }) {
    return Card(
      elevation: 2.0,
      color: kColorCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => YoutubePlayerPage(videoId: videoId, title: title),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16.0)),
                  child: Image.network(
                    imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(
                          child: Icon(Icons.broken_image, size: 50)),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 40),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kColorTextTitle)),
                  const SizedBox(height: 8.0),
                  Text(description,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: kColorTextSubtitle,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class YoutubePlayerPage extends StatelessWidget {
  final String videoId;
  final String title;
  const YoutubePlayerPage(
      {super.key, required this.videoId, required this.title});

  @override
  Widget build(BuildContext context) {
    final controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: YoutubePlayer(
        controller: controller,
        showVideoProgressIndicator: true,
      ),
    );
  }
}
