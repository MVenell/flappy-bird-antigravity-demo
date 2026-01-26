import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const SynthwaveFlappyApp());
}

class SynthwaveFlappyApp extends StatelessWidget {
  const SynthwaveFlappyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0221),
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Game state
  bool gameHasStarted = false;
  bool gameOver = false;
  int score = 0;
  int highscore = 0;

  // Physics constants
  static const double gravity = 0.0007;
  static const double jumpStrength = -0.012;
  static const double birdWidth = 40.0;
  static const double birdHeight = 30.0;
  static const double pipeWidth = 60.0;
  static const double gapHeight = 310.0;

  // Bird position & velocity
  double birdY = 0;
  double birdVelocity = 0;
  double birdRotation = 0;

  // Pipes
  List<double> pipeX = [2, 3.5];
  List<double> pipeHeights = [200, 300]; // Height of the top pipe

  // Particles
  List<Particle> particles = [];
  final Random random = Random();

  // Animation controllers for UI
  late AnimationController _pulseController;
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration duration) {
    if (!gameHasStarted || gameOver) return;

    setState(() {
      // Apply gravity
      birdVelocity += gravity;
      birdY += birdVelocity;

      // Bird rotation based on velocity
      birdRotation = (birdVelocity * 5).clamp(-0.5, 0.5);

      // Create trail particles
      if (random.nextDouble() > 0.5) {
        particles.add(Particle(
          x: -0.2, // Relative to bird center
          y: birdY,
          color: random.nextBool() ? const Color(0xFFFF00E0) : const Color(0xFF00F0FF),
          vx: -0.02 - random.nextDouble() * 0.02,
          vy: (random.nextDouble() - 0.5) * 0.01,
          life: 1.0,
        ));
      }

      // Update particles
      for (var p in particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.life -= 0.02;
      }
      particles.removeWhere((p) => p.life <= 0);

      // Move pipes
      for (int i = 0; i < pipeX.length; i++) {
        pipeX[i] -= 0.015;

        // Reset pipe if it goes off screen
        if (pipeX[i] < -1.5) {
          pipeX[i] += 3;
          pipeHeights[i] = 100 + random.nextDouble() * 300;
          score++;
        }
      }

      // Collision detection
      _checkCollisions();
    });
  }

  void _checkCollisions() {
    // Screen boundaries
    if (birdY > 1 || birdY < -1.1) {
      _endGame();
      return;
    }

    // Pipe collisions
    for (int i = 0; i < pipeX.length; i++) {
      if (pipeX[i] > -0.3 && pipeX[i] < 0.3) {
        // Vertical check
        double screenHeight = MediaQuery.of(context).size.height;
        double birdPixelY = (birdY + 1) * (screenHeight / 2);
        
        // Top pipe collision
        if (birdPixelY < pipeHeights[i]) {
          _endGame();
        }
        // Bottom pipe collision
        if (birdPixelY > pipeHeights[i] + gapHeight) {
          _endGame();
        }
      }
    }
  }

  void _startGame() {
    setState(() {
      gameHasStarted = true;
      gameOver = false;
      score = 0;
      birdY = 0;
      birdVelocity = 0;
      pipeX = [1.5, 3.0];
      particles.clear();
      _ticker.start();
    });
  }

  void _endGame() {
    _ticker.stop();
    setState(() {
      gameOver = true;
      if (score > highscore) {
        highscore = score;
      }
    });
  }

  void _jump() {
    if (gameOver) {
      _startGame();
      return;
    }
    if (!gameHasStarted) {
      _startGame();
    }
    setState(() {
      birdVelocity = jumpStrength;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _jump,
        child: Stack(
          children: [
            // 1. Background Grid & Gradient
            const BackgroundWidget(),

            // 2. Synthwave Sun
            Align(
              alignment: const Alignment(0, -0.6),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.orange.shade700,
                      Colors.red.shade900,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.5),
                      blurRadius: 100,
                      spreadRadius: 20,
                    )
                  ],
                ),
              ),
            ),

            // 3. Particles
            ...particles.map((p) => AnimatedPositioned(
              duration: Duration.zero,
              left: (p.x + 1) * (MediaQuery.of(context).size.width / 2) + 20,
              top: (p.y + 1) * (MediaQuery.of(context).size.height / 2) + 15,
              child: Container(
                width: 6 * p.life,
                height: 6 * p.life,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.color.withOpacity(p.life),
                  boxShadow: [
                    BoxShadow(color: p.color, blurRadius: 4),
                  ],
                ),
              ),
            )),

            // 4. Pipes
            for (int i = 0; i < pipeX.length; i++) ...[
              // Top Pipe
              Positioned(
                left: (pipeX[i] + 1) * (MediaQuery.of(context).size.width / 2) - pipeWidth / 2,
                top: 0,
                child: NeonPipe(height: pipeHeights[i], isTop: true),
              ),
              // Bottom Pipe
              Positioned(
                left: (pipeX[i] + 1) * (MediaQuery.of(context).size.width / 2) - pipeWidth / 2,
                top: pipeHeights[i] + gapHeight,
                child: NeonPipe(
                  height: max(0, MediaQuery.of(context).size.height - (pipeHeights[i] + gapHeight)),
                  isTop: false,
                ),
              ),
            ],

            // 5. Bird
            AnimatedContainer(
              alignment: Alignment(0, birdY),
              duration: Duration.zero,
              child: Transform.rotate(
                angle: birdRotation,
                child: const NeonBird(),
              ),
            ),

            // 6. UI Overlay (Glassmorphism)
            if (!gameHasStarted || gameOver) _buildOverlay(),

            // 7. Score Display
            if (gameHasStarted && !gameOver)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    score.toString(),
                    style: const TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Color(0xFF00F0FF), blurRadius: 20),
                        Shadow(color: Color(0xFFFF00E0), blurRadius: 10),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gameOver ? "TERMINATED" : "NEON FLAP",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: gameOver ? const Color(0xFFFF0055) : const Color(0xFF00F0FF),
                    shadows: [
                      Shadow(
                        color: gameOver ? const Color(0xFFFF0055) : const Color(0xFF00F0FF),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (gameOver) ...[
                  Text("SCORE: $score", style: const TextStyle(fontSize: 20)),
                  Text("BEST: $highscore", style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 20),
                ],
                ScaleTransition(
                  scale: _pulseController.drive(Tween(begin: 1.0, end: 1.1)),
                  child: Text(
                    "TAP TO BOOT",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NeonBird extends StatelessWidget {
  const NeonBird({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFF00F0FF),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0xFF00F0FF), blurRadius: 15, spreadRadius: 2),
        ],
      ),
      child: Stack(
        children: [
          // Eye
          Positioned(
            right: 8,
            top: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Wing
          Positioned(
            left: 5,
            bottom: 5,
            child: Container(
              width: 15,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NeonPipe extends StatelessWidget {
  final double height;
  final bool isTop;

  const NeonPipe({super.key, required this.height, required this.isTop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1B0238).withOpacity(0.8),
        borderRadius: isTop 
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(
          color: const Color(0xFFFF00E0).withOpacity(0.8),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF00E0).withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class BackgroundWidget extends StatelessWidget {
  const BackgroundWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Starfield
        Positioned.fill(
          child: CustomPaint(
            painter: StarFieldPainter(),
          ),
        ),
        // Horizon Glow
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFFFF00E0).withOpacity(0.1),
                  const Color(0xFF00F0FF).withOpacity(0.2),
                ],
              ),
            ),
          ),
        ),
        // Grid
        Positioned.fill(
          child: CustomPaint(
            painter: GridPainter(),
          ),
        ),
      ],
    );
  }
}

class StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    final paint = Paint()..color = Colors.white;
    for (int i = 0; i < 100; i++) {
      paint.color = Colors.white.withOpacity(random.nextDouble() * 0.5);
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), random.nextDouble() * 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00F0FF).withOpacity(0.2)
      ..strokeWidth = 1.0;

    double horizon = size.height * 0.7;

    // Horizontal lines with perspective
    for (double i = 0; i < 10; i++) {
      double y = horizon + pow(i / 10, 2) * (size.height - horizon);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Vertical lines with perspective
    for (double i = -5; i <= 15; i++) {
      double xTop = size.width / 2 + (i - 5) * 20;
      double xBottom = size.width / 2 + (i - 5) * 100;
      canvas.drawLine(Offset(xTop, horizon), Offset(xBottom, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class Particle {
  double x, y, vx, vy, life;
  Color color;
  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.color,
  });
}
