import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/data/avatars.dart';
import 'package:frontend/providers/signup_provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/providers/auth_repository_provider.dart';
import 'package:routemaster/routemaster.dart';

class ProfilePic extends ConsumerStatefulWidget {
  const ProfilePic({super.key});
  @override
  ConsumerState<ProfilePic> createState() => _ProfilePicState();
}

class _ProfilePicState extends ConsumerState<ProfilePic> {
  int selectedIndex = 0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final signup = ref.read(signupProvider);
    if (signup.pfp.isNotEmpty) {
      final savedIndex = avatars.indexWhere(
        (avatar) => avatar.id == signup.pfp,
      );
      if (savedIndex >= 0) {
        selectedIndex = savedIndex;
      }
    }
  }

  Future<void> createAccount() async {
    if (isLoading) return;

    final signup = ref.read(signupProvider);
    final username = signup.username.trim();
    final email = signup.email.trim().toLowerCase();
    final password = signup.password;
    final pfp = avatars[selectedIndex].id.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Signup information is missing. Please go back and enter it again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (pfp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an avatar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final signupData = SignupState(
      username: username,
      email: email,
      password: password,
      pfp: pfp,
    );
    ref.read(signupProvider.notifier).setPfp(pfp);
    setState(() {
      isLoading = true;
    });
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final signupResult = await authRepo.signup(signupData);
      if (!mounted) return;
      if (signupResult['success'] != true) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              signupResult['message'] ?? 'Could not create account',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final loginResult = await authRepo.signin(
        email: signupData.email,
        password: signupData.password,
      );
      if (!mounted) return;
      if (loginResult['success'] != true) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loginResult['message'] ??
                  'Account created, but automatic login failed.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final rawUser = loginResult['user'];
      if (rawUser is! Map) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created, but user information was not returned.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final user = Map<String, dynamic>.from(rawUser);
      ref.read(userProvider.notifier).setUser(user);
      ref.read(signupProvider.notifier).reset();
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      Routemaster.of(context).replace('/');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final titleFontSize = isPhone ? 20.0 : 40.0;
    final buttonFontSize = isPhone ? 18.0 : 25.0;
    final mainAvatarSize = isPhone ? 140.0 : 200.0;
    final gridAvatarSize = isPhone ? 70.0 : 45.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text(
          'Avatar',
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: mainAvatarSize,
                height: mainAvatarSize,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  avatars[selectedIndex].asset,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(height: 25),

              Text(
                'Pick an Avatar',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: buttonFontSize,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 15),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: avatars.length,
                itemBuilder: (context, index) {
                  final isSelected = selectedIndex == index;
                  return GestureDetector(
                    onTap: isLoading
                        ? null
                        : () {
                            setState(() {
                              selectedIndex = index;
                            });
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.red, width: 3)
                            : null,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(
                        child: Image.asset(
                          avatars[index].asset,
                          fit: BoxFit.cover,
                          width: gridAvatarSize,
                          height: gridAvatarSize,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : createAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}
