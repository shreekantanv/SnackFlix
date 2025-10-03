import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:snackflix/utils/router.dart';
import 'package:snackflix/l10n/app_localizations.dart';
import '../models/video_item.dart';
import '../services/settings_service.dart';
import '../services/youtube_service.dart';

class ParentSetupScreen extends StatefulWidget {
  const ParentSetupScreen({super.key});

  @override
  State<ParentSetupScreen> createState() => _ParentSetupScreenState();
}

class _ParentSetupScreenState extends State<ParentSetupScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Configuration
  InterventionMode _mode = InterventionMode.nudges;
  String? _videoUrl;
  double _mindfulBreakInterval = 90;
  double _biteInterval = 90;
  bool _useDetectionToReduceNudges = true;
  String _pin = '';

  late final SettingsService _settings;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsService>();

    // Load saved preferences
    _pin = _settings.pin ?? '';
    _biteInterval = _settings.biteInterval;
    _mindfulBreakInterval =
        _settings.mindfulBreakInterval ?? _settings.biteInterval;
    _useDetectionToReduceNudges = _settings.smartVerification;
    _mode = _settings.mode;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _startSession();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return true; // Mode selection always allows proceed
      case 1:
        return _videoUrl != null && _videoUrl!.isNotEmpty;
      case 2:
        return true; // Settings always valid
      case 3:
        return _pin.length == 4;
      default:
        return false;
    }
  }

  void _startSession() {
    final t = AppLocalizations.of(context)!;
    if (_videoUrl == null || _videoUrl!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.invalidUrlSnack)));
      return;
    }

    // Persist settings
    _settings.setBiteInterval(_biteInterval);
    _settings.setMindfulBreakInterval(_mindfulBreakInterval);
    _settings.setSmartVerification(_useDetectionToReduceNudges);
    _settings.setSessionMode(_mode);
    _settings.setPin(_pin);

    Navigator.pushNamed(
      context,
      AppRouter.childPlayer,
      arguments: {
        'videoUrl': _videoUrl,
        'biteInterval': _biteInterval,
        'mindfulBreakInterval': _mindfulBreakInterval,
        'useDetectionToReduceNudges': _useDetectionToReduceNudges,
        'mode': _mode.name,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Session'), elevation: 0),

      // ✅ only progress + pages in the body
      body: Column(
        children: [
          _StepProgressIndicator(currentStep: _currentStep, totalSteps: 4),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ModeSelectionStep(
                  selectedMode: _mode,
                  onModeSelected: (mode) => setState(() => _mode = mode),
                ),
                _VideoSelectionStep(
                  initialUrl: _videoUrl,
                  onVideoSelected: (url) => setState(() => _videoUrl = url),
                ),
                _SettingsStep(
                  mode: _mode,
                  mindfulBreakInterval: _mindfulBreakInterval,
                  biteInterval: _biteInterval,
                  useDetection: _useDetectionToReduceNudges,
                  onMindfulBreakChanged: (v) =>
                      setState(() => _mindfulBreakInterval = v),
                  onBiteIntervalChanged: (v) =>
                      setState(() => _biteInterval = v),
                  onDetectionToggled: (v) =>
                      setState(() => _useDetectionToReduceNudges = v),
                ),
                _PinStep(
                  pin: _pin,
                  onPinChanged: (pin) => setState(() => _pin = pin),
                ),
              ],
            ),
          ),
        ],
      ),

      // ✅ buttons live here now (no more overflow)
      bottomNavigationBar: _NavigationButtons(
        currentStep: _currentStep,
        canProceed: _canProceed,
        onBack: _previousStep,
        onNext: _nextStep,
        isLastStep: _currentStep == 3,
      ),
    );
  }
}

// Progress Indicator
class _StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepProgressIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(totalSteps, (index) {
          final isActive = index <= currentStep;
          final isCompleted = index < currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < totalSteps - 1) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// Step 1: Mode Selection
class _ModeSelectionStep extends StatelessWidget {
  final InterventionMode selectedMode;
  final Function(InterventionMode) onModeSelected;

  const _ModeSelectionStep({
    required this.selectedMode,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Session Mode',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Select how you want the app to encourage mindful eating',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          _ModeCard(
            icon: Icons.visibility_outlined,
            title: 'Observe',
            description: 'Track eating patterns without any interventions',
            isSelected: selectedMode == InterventionMode.observe,
            onTap: () => onModeSelected(InterventionMode.observe),
          ),
          const SizedBox(height: 12),
          _ModeCard(
            icon: Icons.lightbulb_outline,
            title: 'Gentle Nudges',
            description: 'Occasional friendly reminders to eat mindfully',
            isSelected: selectedMode == InterventionMode.nudges,
            recommended: true,
            onTap: () => onModeSelected(InterventionMode.nudges),
          ),
          const SizedBox(height: 12),
          _ModeCard(
            icon: Icons.self_improvement,
            title: 'Mindful Coach',
            description: 'Scheduled mindful eating breaks with guidance',
            isSelected: selectedMode == InterventionMode.coach,
            onTap: () => onModeSelected(InterventionMode.coach),
          ),
          const SizedBox(height: 12),
          _ModeCard(
            icon: Icons.lock_clock,
            title: 'Lock',
            description: 'Pauses video when not eating (not recommended)',
            isSelected: selectedMode == InterventionMode.lock,
            warning: true,
            onTap: () => onModeSelected(InterventionMode.lock),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final bool recommended;
  final bool warning;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    this.recommended = false,
    this.warning = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (recommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'RECOMMENDED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (warning) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'CAUTION',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Step 2: Video Selection
// Step 2: Video Selection - FIXED VERSION
class _VideoSelectionStep extends StatefulWidget {
  final String? initialUrl;
  final Function(String) onVideoSelected;

  const _VideoSelectionStep({this.initialUrl, required this.onVideoSelected});

  @override
  State<_VideoSelectionStep> createState() => _VideoSelectionStepState();
}

class _VideoSelectionStepState extends State<_VideoSelectionStep> {
  late final TextEditingController _urlController;
  late final TextEditingController _searchController;
  late final YouTubeService _youtubeService;

  List<VideoItem> _featuredVideos = [];
  List<VideoItem> _searchResults = [];
  bool _isLoading = true;
  bool _showSearch = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _searchController = TextEditingController();
    _youtubeService = YouTubeService();
    _loadFeaturedVideos();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeaturedVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final videos = await _youtubeService.getFeaturedVideos();
      if (mounted) {
        setState(() {
          _featuredVideos = videos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load videos';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchVideos() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _youtubeService.searchVideos(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Search failed: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _selectVideo(VideoItem video) {
    _urlController.text = video.youtubeUrl;
    widget.onVideoSelected(video.youtubeUrl);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Selected: ${video.title}')),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text?.trim().isNotEmpty == true) {
      _urlController.text = data!.text!.trim();
      widget.onVideoSelected(data.text!.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = _showSearch ? _searchResults : _featuredVideos;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Choose a Video',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pick from suggestions or paste a YouTube URL',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            hintText: 'Paste YouTube URL',
                            prefixIcon: const Icon(Icons.link),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.content_paste),
                              onPressed: _pasteFromClipboard,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: widget.onVideoSelected,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search videos',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onSubmitted: (_) {
                                  setState(() => _showSearch = true);
                                  _searchVideos();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                setState(() => _showSearch = true);
                                _searchVideos();
                              },
                            ),
                            if (_showSearch)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _showSearch = false;
                                    _searchController.clear();
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                        ? Center(child: Text(_error!))
                        : videos.isEmpty
                        ? const Center(child: Text('No videos found'))
                        : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 16 / 11,
                      ),
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final video = videos[index];
                        return InkWell(
                          onTap: () => _selectVideo(video),
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    video.thumbnailUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                video.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Step 3: Settings
class _SettingsStep extends StatelessWidget {
  final InterventionMode mode;
  final double mindfulBreakInterval;
  final double biteInterval;
  final bool useDetection;
  final Function(double) onMindfulBreakChanged;
  final Function(double) onBiteIntervalChanged;
  final Function(bool) onDetectionToggled;

  const _SettingsStep({
    required this.mode,
    required this.mindfulBreakInterval,
    required this.biteInterval,
    required this.useDetection,
    required this.onMindfulBreakChanged,
    required this.onBiteIntervalChanged,
    required this.onDetectionToggled,
  });

  @override
  Widget build(BuildContext context) {
    final isLegacyMode = mode == InterventionMode.lock;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adjust Settings',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isLegacyMode
                ? 'Configure how long before pausing the video'
                : 'Configure mindful eating break frequency',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          if (!isLegacyMode) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Break Interval',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${mindfulBreakInterval.toInt()}s',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'How often to show mindful eating reminders',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Slider(
                      value: mindfulBreakInterval,
                      min: 45,
                      max: 180,
                      divisions: 27,
                      onChanged: onMindfulBreakChanged,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: useDetection,
              onChanged: onDetectionToggled,
              title: const Text('Smart Detection'),
              subtitle: const Text('Skip reminders when actively eating'),
              secondary: const Icon(Icons.psychology),
            ),
          ] else ...[
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pause Delay',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${biteInterval.toInt()}s',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Time before video pauses when not eating',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Slider(
                      value: biteInterval,
                      min: 45,
                      max: 180,
                      divisions: 27,
                      onChanged: onBiteIntervalChanged,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Step 4: PIN
class _PinStep extends StatelessWidget {
  final String pin;
  final Function(String) onPinChanged;

  const _PinStep({required this.pin, required this.onPinChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Parent PIN',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a 4-digit PIN to control session settings',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          Center(
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.lock,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 32,
                          letterSpacing: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: '••••',
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        maxLength: 4,
                        onChanged: onPinChanged,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      pin.length == 4
                          ? 'PIN is ready!'
                          : 'Enter ${4 - pin.length} more digit${4 - pin.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: pin.length == 4
                            ? Colors.green
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Navigation Buttons
class _NavigationButtons extends StatelessWidget {
  final int currentStep;
  final bool canProceed;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final bool isLastStep;

  const _NavigationButtons({
    required this.currentStep,
    required this.canProceed,
    required this.onBack,
    required this.onNext,
    required this.isLastStep,
  });

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom; // keyboard height

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: kb), // ✅ lift above keyboard
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              if (currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onBack,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              if (currentStep > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: canProceed ? onNext : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(isLastStep ? 'Start Session' : 'Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
