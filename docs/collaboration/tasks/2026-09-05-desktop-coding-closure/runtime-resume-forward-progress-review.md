# Resume/control-wait review and evidence record

2026-09-09. Root records responsibilities-separated reviewer forward_progress_review outcomes. No full/App or real-process acceptance is implied.

## Task1 staged source and RED

Exact staged diff SHA d24296276fec847473a1e78e766d2b5ae639cf57f83c0a19a318cabed2b27980 independently accepted for one ordinary build and selected no-descendant strict-pool regression. Core cb876452342475d0ecf2c63d405d0fd4d0c1cb178d86d376608720b1ddcf4bf4; BlockingTests0163d21d53e55831bb7d659ea804dcbae2281d843e603de6a7d23bd204fc2d02; EEC unchanged4bff675bbb947ec97ffb4cb1e8bf7dff8bfe65328ca493c6ab3076d214257a54.

Evidence directory: `/var/folders/_9/2080h8b50s94v1ympg0mm8pr0000gn/T/agentloop-resume-progress-20260909.w2sYr31u4P`. Root-owned wrapper records complete logs, joined PID/status, source/script/package manifest and executable hashes before/after.

- task1-red-build1: swift build --product RunTests, PID59678,09:44:39–09:46:06 +08, exit0,86.773260s wall (Swift84.23s). Source309 manifest3100d2219a534ec8808dd1b76e80f851ea1e3ff22482fad1e69a1e1531d31a64 unchanged; RunTests0292f673760eca9a4653b11ad329f8f906ada56c55d19fee4c50e464f0eb5c3d; C helper4d1fca7ceae6e026141917ad884569335e29251be96c4937dab8aded6defe0d2 unchanged. Full log a73e592348289f5d0c933f6b57302c883ec143975687fc67996f3f9697466b50 read through EOF; preexisting CLT flag/rpath, unused ApprovalGate result, deprecated CString, weak-var and EEC warnings retained, not a strict-App claim.
- task1-red-focused1: swift run --skip-build RunTests --filter cliResumeSignalPreservesCooperativeProgress, PID60118,09:46:39–43 +08, exit1,3.939368s wall. Parent1test/0suites/1.188s; strictchild60131 sole no-rescue requirement fails at1.017s after canceledawaiter, exact sentinel, invocation1/SIGCONT19/group31415, byte211, all descriptor outcomes and controller/sibling joins pass. Child rawstatus256 is propagated, no evidence-read or cleanup issue. Source and both binaries unchanged. Full log394b2b395473c9e38e71130184cb8cb47c77703a59db821b66b7f2932a67c83a.

Independent RED review accepted both logs/hashes, joined parent/child status and intended failure. Root authorized only the previously approved helper-body GREEN; regression and unrelated sources stay frozen. Exact GREEN source and workload review still required.

Independent exactGREENreview then accepted diff990d6cb252500ef63ad040827d65ba4ae3c733f051c7e8508481abba0f1461b1: only helper body changes from reviewedRED to retained BlockingProcessOperation + awaited Result.get. Core129dcf9090e7e2461cbf090bda4f2e37d535ffcfd914c434e2914f79eb5d08e2; both testpaths remain frozen. Reviewer admitted one ordinarybuild followed, if successful, by generic/help/resume3testfilter with complete child/join evidence and stable pins. Root executing; not yet claimed GREEN.

## Task1 GREEN and acceptance

task1-green-build1 PID61962,09:53:50–57 +08, exit0,7.019774s wall/Swift6.54s; complete log2647748e7bd6ffa9db559259404832577ad03cf482db0415eb1093f6e39bcfa2. Source309 manifest3a06c97f4914f8eef7db1c35438be15e98bab111cd30f92eaea66ff5b4eb8eec unchanged; RunTests2155101fabfa0e38d7cefea38569b87fba6cad5ff9681c90998b9439aac4a48d; C fixture unchanged. Only duplicateCLTrpath warning, not strictApp verification.

task1-green-focused1 PID62057,09:54:31–34 +08, exit0,2.931520s wall;3tests/0suites/0.175s. Children62068resume/62069help/62070generic all rawstatus0, exactsuccessfiles, no rescue/readerrors, canceledwaiter actualresults plusFD/controller/siblingchecks. Source/binaries unchanged, complete log608949bd554991cfe4240d94b7cc3f380fa3f1f66ba489855d2d701aef1106ad. Root fully read logs; independent reviewer verified hashes/currentpins and accepted Task1 spec, sourcequality andREDGREEN. Task2staging admitted after freshpreimage; actual065/integration/full/App not accepted.

## Task2 staged source

Fresh09:55:37 entry runtime-resume-controlled-entry.json: source3093a06c97f..., EEC4bff675b...; rawbase `/var/folders/_9/2080h8b50s94v1ympg0mm8pr0000gn/T/agentloop-controlled-waits-20260909-20260909-62258-1eqnatd`. Root applied independentlyprepared draft2f9078104928a6685e4fadf19bfdef5039faf861fe870427037ae6267eb90af7 with apply_patch; resultingEEC e3fbaa015bfdf717ea2caeea17d5d916ab0388465255d968a0f9931470e0c3c0, solechangedsource. Exactdelta7740a33709957587f43880487dd3c35d0ce122f7b33e24d418f071cedff276e6 independently accepted. Actualsink and sharedreader are exercised; both boundaryresults/controllers/siblings/descriptors joined before combinednorescueassert; old065defer/oracles/budgets unchanged. Reviewer admitted oneordinarybuild and selected p1f1_065ControlledWaitsPreserveCooperativeProgress. ExpectedRED onlycombinednorescue, bothrescues observed; differentfailure requires review. Root executing, no actual065.

Task1 raw evidence is now durably copied without deleting originals: runtime-resume-forward-progress-evidence,24 files, manifest3487a8faae5adfed15a5677eeb573df6bb930f14654c3ca289b5ab3d8fad5e05.

Task2RED independentlyaccepted: red-build1 PID62451,09:56:52–09:57:20 +08, exit0,27.680070s wall/Swift25.00s; full log6e8951f3f29c459684e27a9ba36194e95d0d0407a0464fd80541a2f5628693fd, existingwarningsonly. Source309bd69ad66dd507fa1bce3db587078892d62be25c57624a3e5515517a5f51b17c5 unchanged; RunTestsfb9e67994e986f023afd907e3d6400c3b8181bbf372150fe4a57a380cc79a780. red-focused1 PID62667,09:57:51–56, exit1,4.861616s wall;1test/1suite/2.189s. Strictchild62767 solecombinednorescuefailure2.024s, bothrescuestrue withgateentry/release1, canceledwaiters, exactbytes27/twolines/EOF, controller/sibling/FDchecks beforeassert. Childraw256 propagated; no evidence-readerrors. Logda0dd4b8dce4d66f6c01bf38b4c1a826c219f842d34987133fca19ca238c6309; source/binaries unchanged. Rootandindependentreviewer readactualoutputs; onlywrapperbodyGREEN authorized to solewriter, alltests frozen.

Task2minimalGREEN EECdd0a9a6c6df7831996f3b8cbe452fe10cd381c2a6624150f94d0d98327031cad and exactdeltac9b7ea3d5d234310b75271016c62bb72e85d6a46ff45be1871b44a618e2a0d79 independentlyapproved beforebuild. Onlysharedwrapper bodyawaits BlockingProcessOperation Result; regressionunchanged.

green-build1 PID63386,10:01:52–10:02:16 +08, exit0,24.145833s wall/Swift23.66s, logca56847a5de02361310564d4af55953a52fb8440db3102f14ac9489cf7dff38d. Source3098baa0a8aaf773a7ad17c153483292cc9e12edcc040f52c572f8acc5ac00f7c7a unchanged, RunTests461fa7e2c8802b07bdc44e87077b8c4953e8884881b60a16902633abc33e7b12, Chelperunchanged. green-focused1 PID63456,10:02:30–33, exit0,2.893021s wall;1test/1suite/0.159s, strictchild63464raw0/.015s bothrescuesfalse, alloriginalresource/resultchecks pass, exactsuccessfile, no evidence-readerrors. Log5b78e56ff811b3cf6f662638c3d293c4aa21fd439ed063c82d940da8f381f2b7 andsource/binariesunchanged. Rootreadcompleteoutputs; independentfinalreviewpending. Noactual065/integration/full/Appclaim.

Final independentTask2review accepted spec/sourcequality/REDGREEN afterverifyinglogs, joins, pins andbothrescuefalse. Raw22filesdurablycopied to runtime-resume-controlled-evidence, manifestb99b47e83269aff670ea781e2a9511cca46a175d25b010db4bf050c1e12c1635, originalsretained. This completes both tasks of this plan only; subsequentrealprocess/CLI152/full/Appgates remain.

## Subsequent source-only plans

Reviewer independently approved runtime-cli152-phase-plan.md for source staging after active workload completion and fresh preimages. The seeded actual-recorder audit proves test phase ordering, not real held-pipe production behavior. No new deadline/process or weakened assertions.

Reviewer also approved the refined abort-containment API for source preparation: explicit abort wakes both waiter forms; registered nonblocking socket precedes connect; synchronized shutdown and late identity; complete epilogue. Exact review must check partial I/O/EINTR/EAGAIN, asynchronously joined guard, one-shot containment and error-preserving joins. No real065 invocation is admitted by that design review.
