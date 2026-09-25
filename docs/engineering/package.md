# Package engineering rules: skeleton_shimmer

Rules-Version: skeleton_shimmer/7b89a636754f521b14dd74494ce638cd945e6c4c51fff2356f0183bf6e3160c5
Core-Version: 1
Core-Digest: 1825fa7ff346dca23e65b1b3bf9b2e3e06959f1414bae9952d596d2f62f09b8f
Survey-Digest: f90f45c8a172068c3ed3b9488ba5a7cb4e58efa93c380d2d9a70b399349ec35e
Evidence-Revision: 59d173c
Verified-Revision: unverified

Read CONTRIBUTING.md and docs/engineering/debt.json before editing.

## Current architecture
HEAD 59d173c (2026-08-29), version 1.2.2, 30 commits. It is API compatible with the shimmer package (flutter >=3.22.0, sdk ^3.4.0). The only dependency is the Flutter SDK. lib uses only widgets, foundation and rendering (no Material). There are two implementation files. shimmer.dart: Shimmer, ShimmerScope, _Sweep as the single owner of the clock and loop counting, the shader window computation, and the scope frame _ScopeFrame. skeletons.dart: stateless placeholders excluded from semantics. ShimmerScope is optional. Each Shimmer below it reads the single clock, resolves its own position in the scope box, and paints its slice of the band. Reduced motion freezes the band. There is no hook/ or bin/. AGENTS.md is written for an agent that uses the package. There is a .pubignore at the root.

## Layers and responsibilities
- lib/skeleton_shimmer.dart: A show-listed export.
- lib/src/shimmer.dart: Shimmer (its own _Sweep when standalone, the scope clock under a scope), ShimmerScope (shared clock and frame), _Sweep (loop counting), ShaderMask window geometry, freezing through reduced motion, semantics label.
- lib/src/skeletons.dart: SkeletonBox, SkeletonCircle, SkeletonLine. Placeholders with a fixed look, wrapped in ExcludeSemantics.
- tool/, example/: Media production scripts; a demo with a shared sweep and a reduced motion toggle.

## Public API and dependency direction
lib/skeleton_shimmer.dart does a show-listed export: Shimmer (Shimmer() and Shimmer.fromColors), ShimmerDirection and ShimmerScope (shimmer.dart); SkeletonBox, SkeletonCircle and SkeletonLine (skeletons.dart). Private names: _ShimmerScopeState, _ShimmerScopeMarker, _ScopeFrame, _neverTicks, _ShimmerState, _Sweep, _defaultBone.

shimmer.dart → flutter foundation/rendering/widgets. skeletons.dart → flutter widgets. The two files do not import each other. Inside shimmer.dart, _ShimmerState reads the clock and frame members of _ShimmerScopeState. Both use _Sweep. Direction: widgets → _Sweep. The Scope and Shimmer must stay in the same library.

## Error, state and platform contracts
- Single responsibility helper: _Sweep keeps the clock and loop counting in one place. Its dartdoc states the rationale (shimmer.dart:456-505).
- Scope pattern: an InheritedWidget marker + a render frame. The offset is resolved during painting (shimmer.dart:283-304, 410-433).
- Accessibility: placeholders are wrapped in ExcludeSemantics. The loading state is announced as a liveRegion with semanticsLabel. There is no default English text in lib.
- Reduced motion: the band is frozen with MediaQuery.maybeDisableAnimationsOf. Content is not hidden.
- Diagnostics: public widgets have debugFillProperties.
- Error contract: no exception and no assert. Input is not validated.
- Configuration: constructor parameters match the shimmer package. The Scope owns period and loop. Color, direction and enabled stay on each Shimmer.
- No FFI and no platform check. Streams/cancellation: AnimationController status listener and dispose. In the frozen state it listens to the _neverTicks Listenable, which never fires.
- The figure producing tests assert the figure's claim before writing it (comment in ci.yaml).

## Package rules
### skeleton_shimmer/SS-01 [MUST]
Export public API only from lib/skeleton_shimmer.dart through explicit show lists.
Reason: Internal types (_Sweep, the scope pointer) stay outside thanks to the show lists.
Evidence: lib/skeleton_shimmer.dart:6-7
Evidence role: current-pattern
Existing violation: none

### skeleton_shimmer/SS-02 [MUST]
Keep API and sweep geometry compatible with the shimmer package: Shimmer, Shimmer.fromColors, a 1500 ms default period, loop 0 meaning forever, enabled: false pausing in place, and a paint window three times the child extent.
Reason: The library doc and the pubspec description promise compatibility with the shimmer package.
Evidence: lib/skeleton_shimmer.dart:1-3; lib/src/shimmer.dart:23-26, 38-84, 96-113, 435-453; pubspec.yaml description
Evidence role: current-pattern
Existing violation: none

### skeleton_shimmer/SS-03 [MUST]
Clock and loop accounting live only in _Sweep. Shimmer and ShimmerScope each own a _Sweep and do not drive an AnimationController loop themselves.
Reason: The _Sweep dartdoc records why this logic must stay in one place; two copies would invite subtle bugs.
Evidence: lib/src/shimmer.dart:456-505, 231-235, 346, 363-367
Evidence role: current-pattern
Existing violation: none

### skeleton_shimmer/SS-04 [MUST]
Honour reduced motion through MediaQuery.maybeDisableAnimationsOf by freezing the band. Never hide content for it.
Reason: The package promise (pubspec description) and the reduced motion figure test in CI require this.
Evidence: lib/src/shimmer.dart:33-35, 262-270, 329-330, 357-368; test/reduced_motion_capture_test.dart; pubspec.yaml description
Evidence role: current-pattern
Existing violation: none

### skeleton_shimmer/SS-05 [MUST]
Placeholders are excluded from semantics. The loading state is announced once through Shimmer.semanticsLabel as a live region, and lib ships no default user-facing strings.
Reason: Placeholders carry no content. The semanticsLabel dartdoc explains, as a localization rationale, why there is no default English text.
Evidence: lib/src/skeletons.dart:28-39, 57-64; lib/src/shimmer.dart:115-131, 377-390; test/semantics_test.dart
Evidence role: current-pattern
Existing violation: none

### skeleton_shimmer/SS-06 [MUST]
A Shimmer without a ShimmerScope keeps its pre-scope behaviour. Scope support stays additive.
Reason: The ShimmerScope dartdoc writes this as a contract. _shaderRect uses the old path when there is no scope.
Evidence: lib/src/shimmer.dart:187-188, 410-433
Evidence role: current-pattern
Existing violation: none

### skeleton_shimmer/SS-07 [MUST]
Keep Shimmer and ShimmerScope in one library. _ShimmerState reads the scope's private clock and frame.
Reason: The scope state is private to the library; splitting the two classes would require opening a public surface.
Evidence: lib/src/shimmer.dart:237-248, 317-325, 332-349, 421-433
Evidence role: current-pattern
Existing violation: none

### skeleton_shimmer/SS-08 [MUST]
A capture test that writes a README figure asserts what the figure shows before writing it, and CI runs it.
Reason: The CI comment aims to stop the published figure from drifting away from the code.
Evidence: .github/workflows/ci.yaml (two --tags demo steps and their comment); test/reduced_motion_capture_test.dart; test/sync_capture_test.dart; test/doc_capture_support.dart:1-2
Evidence role: current-pattern
Existing violation: none

### skeleton_shimmer/SS-09 [SHOULD]
lib depends on flutter widgets, foundation and rendering only, with no Material import.
Reason: There is no Material import today; the package also works in apps that do not use Material.
Evidence: lib/src/shimmer.dart:1-3; lib/src/skeletons.dart:1
Evidence role: current-pattern
Existing violation: none

### skeleton_shimmer/SS-10 [SHOULD]
A public widget with configuration reports it in debugFillProperties.
Reason: Shimmer and ShimmerScope do this. The skeleton widgets do not; it was not counted as debt because it is small.
Evidence: lib/src/shimmer.dart:136-146, 218-226
Evidence role: both
Existing violation: none

## Required verification
- Working directory: repository root; command: flutter pub get; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:22.
- Working directory: repository root; command: dart format --output=none --set-exit-if-changed .; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:23.
- Working directory: repository root; command: flutter analyze; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:24.
- Working directory: repository root; command: flutter test --exclude-tags demo; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:25.
- Working directory: repository root; command: flutter test --tags demo test/reduced_motion_capture_test.dart; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:35.
- Working directory: repository root; command: flutter test --tags demo test/sync_capture_test.dart; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:36.
- Working directory: example; command: flutter pub get; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:38.
- Working directory: example; command: flutter analyze; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:40.
Not verified by the survey:
- Analysis, test and format were not run (read only). CI history was not measured (no network).
- The difference between the working tree and HEAD was not measured. Line evidence refers to HEAD 59d173c.
- The exact match with the real stops values and window geometry of the shimmer package was not verified against the live source (no network).
- Test bodies were not read. Only the case counts and the head of doc_capture_support.dart were read.
- tool/build_media.sh and tool/capture_reduced_motion.sh were not read.
- Test coverage percentage was not measured.

## Existing debt
The complete register is docs/engineering/debt.json.
- skeleton_shimmer-D001 | small | lib/src/shimmer.dart:43-44, 57-58, 194-195 | duplicate default value
  Fix: Define private _defaultPeriod and _defaultLoop constants; let all three constructors use them.
  Closure: Private _defaultPeriod and _defaultLoop constants supply all three constructors. The 1500 ms period and the loop 0 meaning stay unchanged.
- skeleton_shimmer-D002 | small | lib/src/shimmer.dart:76-83 | external constant without a source (J3/D16)
  Fix: Verify the source live, then add the link and an 'as of' version or date. If it cannot be verified, do not write the claim.
  Closure: The dartdoc on the stops list carries a verified source link with an as-of version or date, or the unverified claim is removed.
- skeleton_shimmer-D003 | small | .github/workflows/ci.yaml (channel: stable); pubspec.yaml environment | CI coverage gap
  Fix: Add 3.22.0 to the matrix; let the format check run on stable only.
  Closure: The CI matrix includes Flutter 3.22.0 beside stable, with the format check on stable only.
