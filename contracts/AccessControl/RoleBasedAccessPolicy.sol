pragma solidity 0.4.15;

import './IAccessPolicy.sol';
import './IAccessControlled.sol';
import './AccessControlled.sol';
import '../Reclaimable.sol';


/// @title access policy based on Access Control Lists concept
/// @dev Allows to assign an address to a set of roles (n:n relation) and querying if such specific assignment exists.
///     This assignment happens in two contexts:
///         - contract context which allows to build a set of local permissions enforced for particular contract
///         - global context which defines set of global permissions that apply to any contract using this RoleBasedAccessPolicy as Access Policy
///     Permissions are cascading as follows
///         - evaluate permission for given subject for given object (local context)
///         - evaluate permission for given subject for all objects (global context)
///         - evaluate permissions for any subject (everyone) for given object (everyone local context)
///         - evaluate permissions for any subject (everyone) for all objects (everyone global context)
///         - if still unset then disallow
///     Permission is cascaded up only if it was evaluated as Unset at particular level. See EVERYONE and GLOBAL definitions for special values (they are 0x0 addresses)
///     RoleBasedAccessPolicy is its own policy. When created, creator has ROLE_ACCESS_CONTROLLER role. Right pattern is to transfer this control to some other (non deployer) account and then destroy deployer private key.
///     See IAccessControlled for definitions of subject, object and role
contract RoleBasedAccessPolicy is
    IAccessPolicy,
    AccessControlled,
    Reclaimable
{

    ////////////////
    // Types
    ////////////////

    // Łukasiewicz logic values
    enum TriState {
        Unset,
        Allow,
        Deny
    }

    ////////////////////////
    // Constants
    ////////////////////////

    IAccessControlled private constant GLOBAL = IAccessControlled(0x0);

    address private constant EVERYONE = 0x0;

    ////////////////////////
    // Mutable state
    ////////////////////////

    /// @dev subject → role → object → allowed
    mapping (address =>
        mapping(bytes32 =>
            mapping(address => TriState))) private _access;

    /// @notice used to enumerate all users assigned to given role in object context
    /// @dev object → role → addresses
    mapping (address =>
        mapping(bytes32 => address[])) private _accessList;

    ////////////////////////
    // Events
    ////////////////////////

    /// @dev logs change of permissions, 'controller' is an address with ROLE_ACCESS_CONTROLLER
    event LogAccessChanged(
        address controller,
        address indexed subject,
        bytes32 role,
        address indexed object,
        TriState oldValue,
        TriState newValue
    );

    event LogAccess(
        address indexed subject,
        bytes32 role,
        address indexed object,
        bytes4 verb,
        bool granted
    );

    ////////////////////////
    // Constructor
    ////////////////////////

    function RoleBasedAccessPolicy()
        AccessControlled(this) // We are our own policy. This is immutable.
    {
        // Issue the local and global AccessContoler role to creator
        _access[msg.sender][ROLE_ACCESS_CONTROLLER][this] = TriState.Allow;
        _access[msg.sender][ROLE_ACCESS_CONTROLLER][GLOBAL] = TriState.Allow;
        // Update enumerator accordingly so those permissions are visible as any other
        updatePermissionEnumerator(msg.sender, ROLE_ACCESS_CONTROLLER, this, TriState.Unset, TriState.Allow);
        updatePermissionEnumerator(msg.sender, ROLE_ACCESS_CONTROLLER, GLOBAL, TriState.Unset, TriState.Allow);
    }

    ////////////////////////
    // Public functions
    ////////////////////////

    // Overrides `AccessControlled.setAccessPolicy(IAccessPolicy,address)`
    function setAccessPolicy(IAccessPolicy, address)
        public
        only(ROLE_ACCESS_CONTROLLER)
    {
        // `RoleBasedAccessPolicy` always controls its
        // own access. Disallow changing this by overriding
        // the `AccessControlled.setAccessPolicy` function.
        revert();
    }

    // Implements `IAccessPolicy.allowed(address, bytes32, address, bytes4)`
    function allowed(
        address subject,
        bytes32 role,
        address object,
        bytes4 verb
    )
        public
        // constant // NOTE: Solidity does not allow subtyping interfaces
        returns (bool)
    {
        bool set = false;
        bool allow = false;
        TriState value = TriState.Unset;

        // Cascade local, global, everyone local, everyone global
        value = _access[subject][role][object];
        set = value != TriState.Unset;
        allow = value == TriState.Allow;
        if (!set) {
            value = _access[subject][role][GLOBAL];
            set = value != TriState.Unset;
            allow = value == TriState.Allow;
        }
        if (!set) {
            value = _access[EVERYONE][role][object];
            set = value != TriState.Unset;
            allow = value == TriState.Allow;
        }
        if (!set) {
            value = _access[EVERYONE][role][GLOBAL];
            set = value != TriState.Unset;
            allow = value == TriState.Allow;
        }
        // If none is set then disallow
        if (!set) {
            allow = false;
        }

        // Log and return
        LogAccess(subject, role, object, verb, allow);
        return allow;
    }

    // Assign a role to a user globally
    function setUserRole(
        address subject,
        bytes32 role,
        IAccessControlled object,
        TriState newValue
    )
        public
        only(ROLE_ACCESS_CONTROLLER)
    {
        setUserRolePrivate(subject, role, object, newValue);
    }

    // Atomically change a set of role assignments
    function setUserRoles(
        address[] subjects,
        bytes32[] roles,
        IAccessControlled[] objects,
        TriState[] newValues
    )
        public
        only(ROLE_ACCESS_CONTROLLER)
    {
        require(subjects.length == roles.length);
        require(subjects.length == objects.length);
        require(subjects.length == newValues.length);
        for(uint256 i = 0; i < subjects.length; ++i) {
            setUserRolePrivate(subjects[i], roles[i], objects[i], newValues[i]);
        }
    }

    function getValue(
        address subject,
        bytes32 role,
        IAccessControlled object
    )
        public
        constant
        returns (TriState)
    {
        return _access[subject][role][object];
    }

    function getUsers(
        IAccessControlled object,
        bytes32 role
    )
        public
        constant
        returns (address[])
    {
        return _accessList[object][role];
    }

    ////////////////////////
    // Private functions
    ////////////////////////

    function setUserRolePrivate(
        address subject,
        bytes32 role,
        IAccessControlled object,
        TriState newValue
    )
        private
    {
        // An access controler is not allowed to revoke his own right on this
        // contract. This prevents access controlers from locking themselves
        // out. We also require the current contract to be its own policy for
        // this to work. This is enforced elsewhere.
        require(role != ROLE_ACCESS_CONTROLLER || subject != msg.sender || object != this);

        // Fetch old value and short-circuit no-ops
        TriState oldValue = _access[subject][role][object];
        if(oldValue == newValue) {
            return;
        }

        // Update the mapping
        _access[subject][role][object] = newValue;

        // Update permission in enumerator
        updatePermissionEnumerator(subject, role, object, oldValue, newValue);

        // Log
        LogAccessChanged(msg.sender, subject, role, object, oldValue, newValue);
    }

    function updatePermissionEnumerator(
        address subject,
        bytes32 role,
        IAccessControlled object,
        TriState oldValue,
        TriState newValue
    )
        private
    {
        // Update the list on add / remove
        address[] storage list = _accessList[object][role];
        // Add new subject only when going form Unset to Allow/Deny
        if(oldValue == TriState.Unset && newValue != TriState.Unset) {
            list.push(subject);
        }
        // Remove subject when unsetting Allow/Deny
        if(oldValue != TriState.Unset && newValue == TriState.Unset) {
            for(uint256 i = 0; i < list.length; ++i) {
                if(list[i] == subject) {
                    // replace unset address with last address in the list, cut list size
                    list[i] = list[list.length - 1];
                    delete list[list.length - 1];
                    list.length -= 1;
                    // there will be no more matches
                    break;
                }
            }
        }
    }
}
