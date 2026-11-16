import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../data/user/user_api_service.dart';
import '../services/user_session_manager.dart';
import '../theme/crm_colors.dart';
import '../theme/crm_theme.dart';
import 'root_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Login Screen
// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final result = await UserApiService().login(email, password);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!result.success || result.token == null || result.user == null) {
        _showErrorAlert(
          title: 'Authentication Failed',
          message: result.errorMessage ??
              'You have entered an incorrect email or password.\n\nPlease double-check your credentials. Make sure you are using your assigned CRM email and that CAPS lock is off.',
        );
        return;
      }

      await UserSessionManager.instance.save(result.user!, token: result.token);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RootScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorAlert(
        title: 'Connection Error',
        message: 'Could not connect to the server ($e).',
      );
    }
  }

  void _showErrorAlert({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(message, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isDesktopWidth = size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Animated 3D isometric CAD wireframe background ──────────────
          const Positioned.fill(child: _WireframeBackground()),

          // ── Login card ──────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktopWidth ? 940 : 460,
                  ),
                  child: Card(
                    color: Colors.transparent,
                    elevation: 0,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktopWidth ? 28 : 18,
                        vertical: isDesktopWidth ? 30 : 20,
                      ),
                      child: isDesktopWidth
                          ? Row(
                              children: [
                                Expanded(child: _InfoPanel(theme: theme)),
                                const SizedBox(width: 26),
                                Expanded(
                                  child: _buildForm(theme, compact: false),
                                ),
                              ],
                            )
                          : _buildForm(theme, compact: true),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme, {required bool compact}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact) ...[
            _MobileHeader(theme: theme),
            const SizedBox(height: 18),
          ] else ...[
            Text('Sign In', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Use your assigned CRM account to access your dashboard.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'name@company.com',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              filled: true,
              fillColor: Colors.transparent,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              if (!value.contains('@')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              filled: true,
              fillColor: Colors.transparent,
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Password is required';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _onSignIn,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: SpinKitFoldingCube(
                        color: Colors.white,
                        size: 20.0,
                      ),
                    )
                  : const Text('Sign In'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {},
              child: const Text('Forgot password?'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Wireframe Background
// ─────────────────────────────────────────────────────────────────────────────
class _WireframeBackground extends StatefulWidget {
  const _WireframeBackground();

  @override
  State<_WireframeBackground> createState() => _WireframeBackgroundState();
}

class _WireframeBackgroundState extends State<_WireframeBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: _WireframePainter(t: _controller.value),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3D Eye-Level Perspective Architectural Room Interior Painter
// ─────────────────────────────────────────────────────────────────────────────
class _WireframePainter extends CustomPainter {
  const _WireframePainter({required this.t});

  final double t; // 0..1 loop controller

  static const Color _bg1 = Color(0xFFFFFFFF);
  static const Color _bg2 = Color(0xFFF8FAFC);
  static const Color _cobalt = Color(0xFF1E3A8A); // Main walls & structure
  static const Color _cyan = Color(0xFF0284C7);   // Glass, desks, tech
  static const Color _indigo = Color(0xFF4338CA); // Sofa, chairs, soft furnishings
  static const Color _emerald = Color(0xFF047857);// Indoor plants
  static const Color _amber = Color(0xFFD97706);  // Lights & dimension accents
  static const Color _gridLine = Color(0x0A000000);

  Paint _stroke(Color c, double width, {double opacity = 1.0}) => Paint()
    ..color = c.withValues(alpha: opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  Paint _dot(Color c, {double opacity = 1.0}) => Paint()
    ..color = c.withValues(alpha: opacity)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── 1. Background Gradient ─────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bg1, _bg2],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // ── 2. Eye-Level 3D Camera Setup ───────────────────────────────────────
    // Vanishing Point near center screen horizon
    final vpX = w * 0.50 + math.sin(t * 2 * math.pi) * 12.0;
    final vpY = h * 0.46 + math.cos(t * 2 * math.pi) * 6.0;
    final focal = math.max(w, h) * 0.85;

    // 3D Perspective Projection Function: (X, Y, Z) -> Screen Offset
    // X: left/right (-m to +m), Y: height (0 = floor, 1.6 = eye level, 3.2 = ceiling), Z: depth (distance in front of eye)
    Offset proj(double x, double y, double z) {
      final ez = math.max(0.8, z);
      final scale = focal / ez;
      final sx = vpX + (x * scale);
      final sy = vpY - ((y - 1.6) * scale); // 1.6m eye level height
      return Offset(sx, sy);
    }

    // ── 3. Background 2D CAD Grid Overlay ──────────────────────────────────
    final gridP = Paint()
      ..color = _gridLine
      ..strokeWidth = 0.5;
    for (double gx = 0; gx <= w; gx += 28) {
      canvas.drawLine(Offset(gx, 0), Offset(gx, h), gridP);
    }
    for (double gy = 0; gy <= h; gy += 28) {
      canvas.drawLine(Offset(0, gy), Offset(w, gy), gridP);
    }

    // ── 4. 3D Room Envelope (Floor, Ceiling, Back Wall, Side Walls) ───────
    const wallPWidth = 1.4;
    final mainWallP = _stroke(_cobalt, wallPWidth, opacity: 0.12);
    final secWallP = _stroke(_cobalt, 0.9, opacity: 0.07);
    final floorGridP = _stroke(_cobalt, 0.4, opacity: 0.04);
    final ceilingP = _stroke(_cobalt, 0.4, opacity: 0.04);

    // Room boundaries in meters: X: -3.5 to +3.5, Y: 0 to 3.2, Z: 1.2 (front) to 9.0 (back)
    const zNear = 1.4;
    const zFar = 8.5;
    const xL = -3.4;
    const xR = 3.4;
    const yFloor = 0.0;
    const yCeil = 3.2;

    // 8 Room Corner Vertices
    final nFL = proj(xL, yFloor, zNear); // Near Floor Left
    final nFR = proj(xR, yFloor, zNear); // Near Floor Right
    final nCL = proj(xL, yCeil, zNear);  // Near Ceiling Left
    final nCR = proj(xR, yCeil, zNear);  // Near Ceiling Right

    final fFL = proj(xL, yFloor, zFar);  // Far Floor Left
    final fFR = proj(xR, yFloor, zFar);  // Far Floor Right
    final fCL = proj(xL, yCeil, zFar);   // Far Ceiling Left
    final fCR = proj(xR, yCeil, zFar);   // Far Ceiling Right

    // Back Wall Rect (Far Wall)
    canvas.drawLine(fFL, fFR, mainWallP);
    canvas.drawLine(fFR, fCR, mainWallP);
    canvas.drawLine(fCR, fCL, mainWallP);
    canvas.drawLine(fCL, fFL, mainWallP);

    // Depth Wall Edges (Corner Converging Lines)
    canvas.drawLine(nFL, fFL, mainWallP);
    canvas.drawLine(nFR, fFR, mainWallP);
    canvas.drawLine(nCL, fCL, mainWallP);
    canvas.drawLine(nCR, fCR, mainWallP);

    // 3D Perspective Floor Tile Grid (Z Lines & X Lines)
    for (double fx = xL + 0.6; fx < xR; fx += 0.8) {
      canvas.drawLine(proj(fx, yFloor, zNear), proj(fx, yFloor, zFar), floorGridP);
    }
    for (double fz = zNear + 0.8; fz < zFar; fz += 0.9) {
      canvas.drawLine(proj(xL, yFloor, fz), proj(xR, yFloor, fz), floorGridP);
    }

    // 3D Ceiling Panel Grid
    for (double cx = xL + 1.0; cx < xR; cx += 1.2) {
      canvas.drawLine(proj(cx, yCeil, zNear), proj(cx, yCeil, zFar), ceilingP);
    }
    for (double cz = zNear + 1.2; cz < zFar; cz += 1.4) {
      canvas.drawLine(proj(xL, yCeil, cz), proj(xR, yCeil, cz), ceilingP);
    }

    // ── 5. Left Glass Bay Window (Perspective Floor-to-Ceiling Windows) ────
    final windowP = _stroke(_cyan, 1.1, opacity: 0.10);
    final glassSheenP = _stroke(_cyan, 0.4, opacity: 0.05);
    // Vertical Window Frames on Left Wall
    for (double wz = zNear + 0.5; wz <= zFar - 0.5; wz += 1.5) {
      canvas.drawLine(proj(xL, yFloor + 0.3, wz), proj(xL, yCeil - 0.3, wz), windowP);
    }
    // Horizontal Window Railing Lines
    canvas.drawLine(proj(xL, yFloor + 0.3, zNear), proj(xL, yFloor + 0.3, zFar), windowP);
    canvas.drawLine(proj(xL, 1.1, zNear), proj(xL, 1.1, zFar), windowP);
    canvas.drawLine(proj(xL, yCeil - 0.3, zNear), proj(xL, yCeil - 0.3, zFar), windowP);
    // Glass sheen strokes
    for (double wz = zNear + 1.0; wz < zFar; wz += 2.0) {
      canvas.drawLine(proj(xL, 0.8, wz), proj(xL, 2.4, wz + 0.8), glassSheenP);
    }

    // ── 6. Right Shelving Unit / Wall Bookshelf ────────────────────────────
    final shelfP = _stroke(_cobalt, 1.0, opacity: 0.08);
    const shelfX = xR - 0.1;
    for (double sy = 0.6; sy <= 2.6; sy += 0.5) {
      canvas.drawLine(proj(shelfX - 0.4, sy, zNear + 1.0), proj(shelfX - 0.4, sy, zFar - 1.5), shelfP);
      canvas.drawLine(proj(shelfX, sy, zNear + 1.0), proj(shelfX, sy, zFar - 1.5), shelfP);
      // Vertical supports
      canvas.drawLine(proj(shelfX - 0.4, sy, zNear + 1.0), proj(shelfX, sy, zNear + 1.0), shelfP);
      canvas.drawLine(proj(shelfX - 0.4, sy, zFar - 1.5), proj(shelfX, sy, zFar - 1.5), shelfP);
    }

    // ── 7. 3D Executive Office Workspace (Desk & Chair) ─────────────────────
    final deskP = _stroke(_cyan, 1.2, opacity: 0.12);

    // 3D Executive Desk Cuboid: X: 0.3 to 2.1, Y: 0 to 0.75, Z: 3.2 to 4.6
    _draw3DBox(canvas, proj, 0.3, 0.0, 3.2, 1.8, 0.75, 1.4, deskP);

    // 3D Laptop on Desk Top
    final laptopP = _stroke(_amber, 1.0, opacity: 0.12);
    // Base
    _draw3DBox(canvas, proj, 0.8, 0.75, 3.6, 0.45, 0.02, 0.35, laptopP);
    // Open Screen angled up
    final screenB1 = proj(0.8, 0.77, 3.6);
    final screenB2 = proj(1.25, 0.77, 3.6);
    final screenT1 = proj(0.8, 1.05, 3.45);
    final screenT2 = proj(1.25, 1.05, 3.45);
    canvas.drawLine(screenB1, screenT1, laptopP);
    canvas.drawLine(screenB2, screenT2, laptopP);
    canvas.drawLine(screenT1, screenT2, laptopP);

    // 3D Ergonomic Swivel Chair behind Desk (Z = 4.9)
    final chairP = _stroke(_cobalt, 1.1, opacity: 0.10);
    // Seat Cushion
    _draw3DBox(canvas, proj, 0.9, 0.45, 4.8, 0.5, 0.08, 0.5, chairP);
    // Backrest
    _draw3DBox(canvas, proj, 0.9, 0.53, 5.25, 0.5, 0.55, 0.06, chairP);
    // Center Stem & Star Base
    canvas.drawLine(proj(1.15, 0.0, 5.05), proj(1.15, 0.45, 5.05), chairP);
    for (int i = 0; i < 5; i++) {
      final a = i * (2 * math.pi / 5);
      final bx = 1.15 + math.cos(a) * 0.3;
      final bz = 5.05 + math.sin(a) * 0.3;
      canvas.drawLine(proj(1.15, 0.0, 5.05), proj(bx, 0.0, bz), chairP);
    }

    // ── 8. 3D Living Lounge Sofas & Coffee Table ───────────────────────────
    final sofaP = _stroke(_indigo, 1.2, opacity: 0.11);

    // Main 3D Sofa Couch: X: -3.0 to -1.2, Y: 0 to 0.8, Z: 3.5 to 5.0
    // Seat base
    _draw3DBox(canvas, proj, -2.9, 0.1, 3.5, 1.7, 0.35, 1.3, sofaP);
    // Backrest
    _draw3DBox(canvas, proj, -2.9, 0.45, 4.6, 1.7, 0.40, 0.25, sofaP);
    // Left Armrest
    _draw3DBox(canvas, proj, -3.1, 0.1, 3.5, 0.2, 0.55, 1.35, sofaP);
    // Right Armrest
    _draw3DBox(canvas, proj, -1.2, 0.1, 3.5, 0.2, 0.55, 1.35, sofaP);

    // Distance Lounge Sofa Couch (Back Left Z = 6.2 to 7.3)
    final distSofaP = _stroke(_indigo, 1.0, opacity: 0.07);
    _draw3DBox(canvas, proj, -2.8, 0.08, 6.2, 1.4, 0.32, 1.0, distSofaP);
    _draw3DBox(canvas, proj, -2.8, 0.40, 7.0, 1.4, 0.36, 0.20, distSofaP);
    _draw3DBox(canvas, proj, -2.95, 0.08, 6.2, 0.15, 0.48, 1.0, distSofaP);
    _draw3DBox(canvas, proj, -1.4, 0.08, 6.2, 0.15, 0.48, 1.0, distSofaP);
    // Cushion seam line strokes on distance sofa
    canvas.drawLine(proj(-2.1, 0.40, 6.2), proj(-2.1, 0.40, 7.0), distSofaP);
    canvas.drawLine(proj(-2.1, 0.40, 7.0), proj(-2.1, 0.76, 7.0), distSofaP);

    // 3D Coffee Table in front of Sofa (Z = 2.4 to 3.0)
    final tableP = _stroke(_cyan, 1.1, opacity: 0.09);
    _draw3DBox(canvas, proj, -2.5, 0.0, 2.3, 1.0, 0.38, 0.7, tableP);

    // 3D Perspective Area Rug under Coffee Table
    final rugP = _stroke(_indigo, 0.5, opacity: 0.05);
    _draw3DBox(canvas, proj, -2.8, 0.005, 1.8, 1.6, 0.005, 1.8, rugP);

    // ── 9. 3D Potted Plants & Wall Indoor Tree Wireframe ────────────────────
    final plantP = _stroke(_emerald, 1.0, opacity: 0.09);
    // Plant 1 Pot (Left Corner Z = 7.0)
    _draw3DBox(canvas, proj, -3.0, 0.0, 7.0, 0.4, 0.55, 0.4, plantP);
    // Leaf Wireframe Spines (Eye Level Branching)
    final p1Top = proj(-2.8, 0.55, 7.2);
    for (int i = 0; i < 7; i++) {
      final a = i * (math.pi / 3.5);
      final lx = -2.8 + math.cos(a) * 0.45;
      final ly = 0.55 + math.sin(a * 2.0) * 0.25 + 0.3;
      final lz = 7.2 + math.sin(a) * 0.45;
      canvas.drawLine(p1Top, proj(lx, ly, lz), plantP);
      canvas.drawCircle(proj(lx, ly, lz), 3.0, _dot(_emerald, opacity: 0.09));
    }

    // Plant 2 Pot (Right Back Corner Z = 7.8)
    _draw3DBox(canvas, proj, 2.6, 0.0, 7.8, 0.45, 0.6, 0.45, plantP);
    final p2Top = proj(2.825, 0.6, 8.025);
    for (int i = 0; i < 7; i++) {
      final a = i * (math.pi / 3.5) + 0.4;
      final lx = 2.825 + math.cos(a) * 0.45;
      final ly = 0.6 + math.sin(a * 2.0) * 0.25 + 0.3;
      final lz = 8.025 + math.sin(a) * 0.45;
      canvas.drawLine(p2Top, proj(lx, ly, lz), plantP);
      canvas.drawCircle(proj(lx, ly, lz), 3.0, _dot(_emerald, opacity: 0.09));
    }

    // Background Wall Small Tree Wireframe (Center-Left Wall Z = 8.2)
    final treeTrunkP = _stroke(_emerald, 1.2, opacity: 0.11);
    final treeBranchP = _stroke(_emerald, 0.9, opacity: 0.08);
    final treeFoliageP = _stroke(_emerald, 0.6, opacity: 0.06);

    // Wall Pot Container against Back Wall
    _draw3DBox(canvas, proj, -0.6, 0.0, 8.1, 0.4, 0.45, 0.4, treeTrunkP);
    // Trunk & Main Branching
    final potCenterTop = proj(-0.4, 0.45, 8.3);
    final trunkFork = proj(-0.4, 1.1, 8.3);
    canvas.drawLine(potCenterTop, trunkFork, treeTrunkP);

    final branch1 = proj(-0.75, 1.45, 8.2);
    final branch2 = proj(-0.15, 1.55, 8.4);
    final branch3 = proj(-0.4, 1.7, 8.3);
    canvas.drawLine(trunkFork, branch1, treeBranchP);
    canvas.drawLine(trunkFork, branch2, treeBranchP);
    canvas.drawLine(trunkFork, branch3, treeBranchP);

    final sub1 = proj(-0.95, 1.7, 8.1);
    final sub2 = proj(-0.6, 1.8, 8.2);
    final sub3 = proj(0.05, 1.8, 8.5);
    final sub4 = proj(-0.25, 1.95, 8.3);
    canvas.drawLine(branch1, sub1, treeBranchP);
    canvas.drawLine(branch1, sub2, treeBranchP);
    canvas.drawLine(branch2, sub3, treeBranchP);
    canvas.drawLine(branch3, sub4, treeBranchP);

    final leafNodes = [branch1, branch2, branch3, sub1, sub2, sub3, sub4];
    for (final node in leafNodes) {
      canvas.drawCircle(node, 6.0, treeFoliageP);
      canvas.drawCircle(node, 2.5, _dot(_emerald, opacity: 0.08));
    }

    // ── 10. 3D Wall Painting Artwork on Back Wall ───────────────────────────
    final paintingFrameP = _stroke(_indigo, 1.1, opacity: 0.10);
    final paintingArtP = _stroke(_cyan, 0.8, opacity: 0.07);
    // Framed Canvas on Back Wall (X: 0.5 to 1.8, Y: 1.3 to 2.3, Z: 8.45)
    final ptl = proj(0.5, 2.3, 8.45);
    final ptr = proj(1.8, 2.3, 8.45);
    final pbr = proj(1.8, 1.3, 8.45);
    final pbl = proj(0.5, 1.3, 8.45);
    canvas.drawLine(ptl, ptr, paintingFrameP);
    canvas.drawLine(ptr, pbr, paintingFrameP);
    canvas.drawLine(pbr, pbl, paintingFrameP);
    canvas.drawLine(pbl, ptl, paintingFrameP);
    // Inner matting border
    final mtl = proj(0.6, 2.2, 8.45);
    final mtr = proj(1.7, 2.2, 8.45);
    final mbr = proj(1.7, 1.4, 8.45);
    final mbl = proj(0.6, 1.4, 8.45);
    canvas.drawLine(mtl, mtr, paintingFrameP);
    canvas.drawLine(mtr, mbr, paintingFrameP);
    canvas.drawLine(mbr, mbl, paintingFrameP);
    canvas.drawLine(mbl, mtl, paintingFrameP);
    // Landscape Mountain & Sun Artwork strokes inside painting
    final mtnPeak1 = proj(0.9, 1.9, 8.45);
    final mtnPeak2 = proj(1.4, 2.05, 8.45);
    canvas.drawLine(mbl, mtnPeak1, paintingArtP);
    canvas.drawLine(mtnPeak1, proj(1.15, 1.5, 8.45), paintingArtP);
    canvas.drawLine(proj(1.15, 1.5, 8.45), mtnPeak2, paintingArtP);
    canvas.drawLine(mtnPeak2, mbr, paintingArtP);
    canvas.drawCircle(proj(1.45, 2.1, 8.45), 4.5, _dot(_amber, opacity: 0.08));

    // ── 11. 3D Ceiling Lights & Pendant Light Bulb ─────────────────────────
    final lightP = _stroke(_amber, 1.0, opacity: 0.09);
    final lightGlowP = _stroke(_amber, 0.4, opacity: 0.04);

    // 4 Ceiling Recessed Panels
    final lightCoords = [
      [-1.8, 3.8], [1.8, 3.8],
      [-1.8, 6.5], [1.8, 6.5]
    ];
    for (final lc in lightCoords) {
      final center = proj(lc[0], yCeil, lc[1]);
      canvas.drawCircle(center, 9.0, lightP);
      canvas.drawCircle(center, 15.0, lightGlowP);
      canvas.drawLine(proj(lc[0] - 0.2, yCeil, lc[1]), proj(lc[0] + 0.2, yCeil, lc[1]), lightP);
    }

    // Hanging Pendant Light Bulb over Desk (Z = 4.0)
    final lampHook = proj(1.2, yCeil, 4.0);
    final lampShade = proj(1.2, 2.1, 4.0);
    canvas.drawLine(lampHook, lampShade, lightP);
    // Light Bulb fixture & outer glow
    canvas.drawCircle(lampShade, 12.0, lightP);
    canvas.drawCircle(lampShade, 6.0, _dot(_amber, opacity: 0.10));
    canvas.drawCircle(lampShade, 20.0, lightGlowP);

    // ── 12. Floating Perspective CAD Node Rings (3D Particle Rings) ────────
    final particlePos = [
      [-1.5, 1.8, 2.5],
      [1.4, 2.1, 3.0],
      [-0.8, 1.2, 4.2],
      [2.2, 1.5, 5.5],
      [-2.2, 2.4, 6.2],
    ];
    for (int i = 0; i < particlePos.length; i++) {
      final pos = particlePos[i];
      final phase = (t + i * 0.2) % 1.0;
      final floatY = pos[1] + math.sin(phase * 2 * math.pi) * 0.2;
      final op = (0.04 + math.sin(phase * math.pi) * 0.06).clamp(0.0, 1.0);
      final center = proj(pos[0], floatY, pos[2]);

      final ringP = _stroke(_cyan, 0.8, opacity: op);
      canvas.drawCircle(center, 8.0, ringP);
      canvas.drawCircle(center, 3.5, _stroke(_indigo, 0.5, opacity: op));
      canvas.drawCircle(center, 2.0, _dot(_amber, opacity: op));
    }

    // ── 13. Eye-Level Perspective Dimension Lines ──────────────────────────
    final dimP = _stroke(_amber, 0.6, opacity: 0.08);
    // Back Wall Height Dimension
    canvas.drawLine(proj(xR + 0.15, yFloor, zFar), proj(xR + 0.15, yCeil, zFar), dimP);
    canvas.drawLine(proj(xR + 0.05, yFloor, zFar), proj(xR + 0.25, yFloor, zFar), dimP);
    canvas.drawLine(proj(xR + 0.05, yCeil, zFar), proj(xR + 0.25, yCeil, zFar), dimP);

    // ── 14. Vertex Node Markers at Key 3D Corners ──────────────────────────
    final nodeDotP = _dot(_cobalt, opacity: 0.10);
    final key3DNodes = [
      nFL, nFR, nCL, nCR, fFL, fFR, fCL, fCR,
      proj(0.3, 0.75, 3.2), proj(2.1, 0.75, 3.2), proj(2.1, 0.75, 4.6), proj(0.3, 0.75, 4.6),
      proj(-2.9, 0.8, 4.6), proj(-1.2, 0.8, 4.6),
    ];
    for (final dot in key3DNodes) {
      canvas.drawCircle(dot, 2.5, nodeDotP);
      canvas.drawCircle(dot, 4.5, _stroke(_cyan, 0.5, opacity: 0.06));
    }
  }

  // Helper: Draw 3D Wireframe Box Cuboid (x, y, z) width(w), height(h), depth(d)
  void _draw3DBox(
    Canvas canvas,
    Offset Function(double, double, double) proj,
    double x, double y, double z,
    double w, double h, double d,
    Paint p,
  ) {
    final v = [
      // Front Face (Z)
      proj(x,     y,     z),
      proj(x + w, y,     z),
      proj(x + w, y + h, z),
      proj(x,     y + h, z),
      // Back Face (Z + d)
      proj(x,     y,     z + d),
      proj(x + w, y,     z + d),
      proj(x + w, y + h, z + d),
      proj(x,     y + h, z + d),
    ];

    // Front & Back Rectangles
    canvas.drawPath(Path()..addPolygon(v.sublist(0, 4), true), p);
    canvas.drawPath(Path()..addPolygon(v.sublist(4, 8), true), p);
    // Connecting Depth Edges
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(v[i], v[i + 4], p);
    }
  }

  @override
  bool shouldRepaint(_WireframePainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────────────────────────
class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(CrmTheme.radiusMd),
            border: Border.all(color: CrmColors.border),
          ),
          child: Image.asset('assets/icon.png'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AESTHETIC INTERIOR', style: theme.textTheme.labelSmall),
              const SizedBox(height: 2),
              Text('Sign In', style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52, height: 52,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(CrmTheme.radiusMd),
                border: Border.all(color: CrmColors.border),
              ),
              child: Image.asset('assets/icon.png'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AESTHETIC INTERIOR', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Operations Management Software',
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'A focused workspace to manage leads, task assignments, follow-ups, and delivery flow.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(CrmTheme.radiusLg),
            border: Border.all(color: CrmColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WHAT THIS SYSTEM COVERS', style: theme.textTheme.labelSmall),
              const SizedBox(height: 10),
              Text('• Lead intake and qualification workflow', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text('• Team assignment by department', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text('• Follow-up, visit, and progress tracking', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
