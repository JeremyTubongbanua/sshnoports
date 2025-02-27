import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';

class ProfileDisplayName extends StatelessWidget {
  const ProfileDisplayName({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileBloc, ProfileState, String?>(
      selector: (ProfileState state) {
        if (state is ProfileLoadedState) {
          return state.profile.displayName;
        }
        return null;
      },
      builder: (BuildContext context, String? displayName) {
        if (displayName == null) return const SizedBox();
        return Text(displayName);
      },
    );
  }
}
