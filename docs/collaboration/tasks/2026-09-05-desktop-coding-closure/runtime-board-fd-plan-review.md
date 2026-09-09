# Board FD isolation — independent parent plan review

Read the full 103-line plan (SHA `2abce42ffc1560a103778e117e08089d62da0ac74d662ce7119882ab056f4ac2`) and both actual test bodies/counter callers, plus the existing owned 075 child resource boundary. Approved for the exact two test files.

The source establishes a measurement-scope mismatch: suite serialization does not isolate a process-global `/dev/fd` count from other concurrently running suites. No production leak is inferred. A separate process for each existing full body retains the original 20/100 iterations, every deadline and `< 10` assertion; a real held-descriptor negative proves failure propagation. Reuse the already reviewed owned runner mechanically in place; no new Sources entry, global serialization, unknown PID/FD signaling, or swallowing cleanup failures.

Failure evidence must distinguish a deliberate FD assertion from setup, containment or resource-owner errors. The new 60-second outer containment is an additional child-lifetime guard, not a replacement for any original test deadline. A positive isolated failure stops acceptance pending its actual cause. Root owns all builds and runtime verification after the writer releases; independent implementation review remains required.
