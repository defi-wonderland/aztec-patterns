# Callback Pattern

/*
    Callback pattern
    =====================
    This is an example of a callback pattern in Aztec.

    There are 2 contracts and 2 parties involved:
    - call_me_back contract: initiate the flow and receiving the callback
    - callbacker contract: store the pending callback and, when resolve() is called, process it
    - Alice: calls the call_me_back contract
    - Bob: trigger the logic on the callbacker contract

    alice calls queue_new_call with bob address as the one who needs to resolve it, bob calls resolve on the resolver contract, which calls the callback function.

    this can be fully public - alive private then bob answer isn't private and the callback fn leaks it - fully private and callback effect if accessible for alice only
    
    This example uses a callback to set a value note for the original sender.
*/