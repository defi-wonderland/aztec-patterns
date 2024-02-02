# Callback Pattern

This is an example of callback patterns in Aztec.

In this example, the callback effect is to set a value note for the original sender, Alice.

Two types of callback are demonstrated: atomic and asynchronous.

There are 2 contracts and 2 parties involved:
- Alice: initiate the flow and receive the effect of the callback
- Bob: trigger the logic on the callbacker contract, if the callback is async (see below)
- call_me_back contract: initiate the flow, calls callbacker and receive the callback
- callbacker contract: either store a pending callback (later resolved by bob) or trigger the callback immediately (if the callback is atomic)

The atomic callback flow is as follow: Alice calls new_atomic_call on call_me_back contract, which calls call_me_now on the resolver contract, which calls the callback function on call_me_back contract.
The async callback flow is as follow: Alice calls new_async_call on call_me_back contract, which calls queue_new_call on the resolver contract and stores the pending callback (in a note for Bob).
Later, Bob calls resolve on the resolver contract, which calls the callback function on call_me_back contract.