pragma solidity 0.4.15;


/// @title state machine for Commitment contract
/// @notice implements following state progression Before --> Whitelist --> Public --> Finished
/// @dev state switching via 'transitionTo' function
/// @dev inherited contract must implement mAfterTransition which will be called just after state transition happened
contract StateMachine {

    ////////////////////////
    // Types
    ////////////////////////

    enum State {
        Before,
        Whitelist,
        Public,
        Finished
    }

    ////////////////////////
    // Mutable state
    ////////////////////////

    // current state
    State private _state = State.Before;

    ////////////////////////
    // Events
    ////////////////////////

    event LogStateTransition(
        State oldState,
        State newState
    );

    ////////////////////////
    // Modifiers
    ////////////////////////

    modifier onlyState(State state) {
        require(_state == state);
        _;
    }

    modifier onlyStates(State state0, State state1) {
        require(_state == state0 || _state == state1);
        _;
    }

    /// @dev Multiple states can be handled by adding more modifiers.
    /* modifier notInState(State state) {
        require(_state != state);
        _;
    }*/

    ////////////////////////
    // Constructor
    ////////////////////////

    function StateMachine() internal {
    }

    ////////////////////////
    // Public functions
    ////////////////////////

    function state()
        public
        constant
        returns (State)
    {
        return _state;
    }

    ////////////////////////
    // Internal functions
    ////////////////////////

    // @dev Transitioning to the same state is silently ignored, no log events
    //  or handlers are called.
    function transitionTo(State newState)
        internal
    {
        State oldState = _state;
        require(validTransition(oldState, newState));

        _state = newState;
        LogStateTransition(oldState, newState);

        // should not change state and it is required here.
        mAfterTransition(oldState, newState);
        require(_state == newState);
    }

    function validTransition(State oldState, State newState)
        private
        constant
        returns (bool valid)
    {
        return (
            oldState == State.Before && newState == State.Whitelist) || (
            oldState == State.Whitelist && newState == State.Public) || (
            oldState == State.Public && newState == State.Finished
        );
    }

    /// @notice gets called after every state transition.
    /// @dev may not change state, transitionTo will revert on that condition
    function mAfterTransition(State oldState, State newState)
        internal;
}
