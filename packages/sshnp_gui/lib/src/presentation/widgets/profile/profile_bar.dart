import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:sshnp_gui/src/controllers/sshnp_config_controller.dart';

class ProfileBar extends ConsumerStatefulWidget {
  final String profileName;
  const ProfileBar(this.profileName, {Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileBar> createState() => _ProfileBarState();
}

class _ProfileBarState extends ConsumerState<ProfileBar> {
  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(paramsFamilyController(widget.profileName));
    return controller.when(
      error: (error, stackTrace) => Container(),
      loading: () => const LinearProgressIndicator(),
      data: (params) => const Row(
        children: [
          
        ],
      ),
    );
  }
}
