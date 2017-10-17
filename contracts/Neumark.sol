pragma solidity 0.4.15;

import './AccessControl/AccessControlled.sol';
import './AccessRoles.sol';
import './Agreement.sol';
import './SnapshotToken/SnapshotToken.sol';
import './NeumarkIssuanceCurve.sol';
import './Reclaimable.sol';


contract Neumark is
    AccessControlled,
    AccessRoles,
    Agreement,
    SnapshotToken,
    NeumarkIssuanceCurve,
    Reclaimable
{

    ////////////////////////
    // Constants
    ////////////////////////

    string private constant TOKEN_NAME = "Neumark";

    uint8  private constant TOKEN_DECIMALS = 18;

    string private constant TOKEN_SYMBOL = "NMK";

    ////////////////////////
    // Mutable state
    ////////////////////////

    bool private _transferEnabled;

    uint256 private _totalEuroUlps;

    ////////////////////////
    // Events
    ////////////////////////

    event LogNeumarksIssued(
        address indexed owner,
        uint256 euroUlp,
        uint256 neumarkUlp
    );

    event LogNeumarksBurned(
        address indexed owner,
        uint256 euroUlp,
        uint256 neumarkUlp
    );

    ////////////////////////
    // Constructor
    ////////////////////////

    function Neumark(
        IAccessPolicy accessPolicy,
        IEthereumForkArbiter forkArbiter
    )
        AccessControlled(accessPolicy)
        AccessRoles()
        Agreement(accessPolicy, forkArbiter)
        SnapshotToken(
            TOKEN_NAME,
            TOKEN_DECIMALS,
            TOKEN_SYMBOL
        )
        NeumarkIssuanceCurve()
        Reclaimable()
    {
        _transferEnabled = true;
        _totalEuroUlps = 0;
    }

    ////////////////////////
    // Public functions
    ////////////////////////

    function issueForEuro(uint256 euroUlps)
        public
        only(ROLE_NEUMARK_ISSUER)
        acceptAgreement(msg.sender)
        returns (uint256)
    {
        require(_totalEuroUlps + euroUlps >= _totalEuroUlps);
        uint256 neumarkUlps = incremental(euroUlps);
        _totalEuroUlps += euroUlps;
        mGenerateTokens(msg.sender, neumarkUlps);
        LogNeumarksIssued(msg.sender, euroUlps, neumarkUlps);
        return neumarkUlps;
    }

    function distributeNeumark(address to, uint256 neumarkUlps)
        public
        only(ROLE_NEUMARK_ISSUER)
        acceptAgreement(to)
    {
        bool success = transfer(to, neumarkUlps);
        require(success);
    }

    function burnNeumark(uint256 neumarkUlps)
        public
        only(ROLE_NEUMARK_BURNER)
        returns (uint256)
    {
        uint256 euroUlps = incrementalInverse(neumarkUlps);
        _totalEuroUlps -= euroUlps;
        mDestroyTokens(msg.sender, neumarkUlps);
        LogNeumarksBurned(msg.sender, euroUlps, neumarkUlps);
        return euroUlps;
    }

    function enableTransfer(bool enabled)
        public
        only(ROLE_TRANSFER_ADMIN)
    {
        _transferEnabled = enabled;
    }

    function createSnapshot()
        public
        only(ROLE_SNAPSHOT_CREATOR)
        returns (uint256)
    {
        return DailyAndSnapshotable.createSnapshot();
    }

    function transferEnabled()
        public
        constant
        returns (bool)
    {
        return _transferEnabled;
    }

    function totalEuroUlps()
        public
        constant
        returns (uint256)
    {
        return _totalEuroUlps;
    }

    function incremental(uint256 euroUlps)
        public
        constant
        returns (uint256 neumarkUlps)
    {
        return incremental(_totalEuroUlps, euroUlps);
    }

    /// @dev The result is rounded down.
    function incrementalInverse(uint256 neumarkUlps)
        public
        constant
        returns (uint256 euroUlps)
    {
        return incrementalInverse(_totalEuroUlps, neumarkUlps);
    }

    ////////////////////////
    // Internal functions
    ////////////////////////

    //
    // Implements MTokenController
    //

    function mOnTransfer(
        address from,
        address, // to
        uint256 // amount
    )
        internal
        acceptAgreement(from)
        returns (bool allow)
    {
        return _transferEnabled;
    }

    function mOnApprove(
        address owner,
        address, // spender,
        uint256 // amount
    )
        internal
        acceptAgreement(owner)
        returns (bool allow)
    {
        return true;
    }
}
