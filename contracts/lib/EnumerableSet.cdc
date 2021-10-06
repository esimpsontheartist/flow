//BASED ON ENUMERABLESET BY OPENZEPPELIN
/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * Only UintSet
 */
pub contract EnumerableSet {
    
    pub struct Set {
        // Storage of set values
        pub var _values: [UInt256]
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        pub var _indexes: {UInt256: UInt256}

        init() {
            self._values = []
            self._indexes = {}
        }
    }

    //struct for multiple return
    pub struct SetReturn {
        pub let set: Set
        pub let present: Bool

        init(_ set: Set, _ present: Bool){
            self.set = set
            self.present = present
        }
    }

    /**
    * @dev Add a value to a set. O(1).
    *
    * Returns the set with the added element and true if the value was added to the set,
    * that is if it was not already present, in which case it returns the same set and false
    */
    priv fun _add(_ set: Set, _ value: UInt256): SetReturn {
        var setCopy = set
        if !self._contains(setCopy, value) {
            setCopy._values.append(value)
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            setCopy._indexes[value] = UInt256(setCopy._values.length);
            return SetReturn(setCopy, true)
        } 
        return SetReturn(setCopy, false)
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns the set with the removed element and true if the value was removed from the set,
     * that is if it was not already present, in which case it returns the same set and false
     */
    priv fun _remove(_ set: Set, _ value: UInt256): SetReturn {
        var setCopy = set
        var valueIndex = setCopy._indexes[value]

        if valueIndex != 0 {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            var toDeleteIndex = valueIndex! - 1;
            var lastIndex = UInt256(setCopy._values.length) - 1

            if lastIndex != toDeleteIndex {
                var lastvalue = setCopy._values[lastIndex]

                // Move the last value to the index where the value to delete is
                setCopy._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                setCopy._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            setCopy._values.removeLast();

            // Delete the index for the deleted slot
            setCopy._indexes.remove(key: value)

            return SetReturn(setCopy, false)
        }

        return SetReturn(setCopy, false)
    }

    /**
    * @dev Returns true if the value is in the set. O(1).
    */
    priv fun _contains(_ set: Set, _ value: UInt256): Bool {
        return set._values[value] != 0
    }

    /**
    * @dev Returns the number of values on the set. O(1).
    */
    priv fun _length(_ set: Set): UInt256 {
        return UInt256(set._values.length)
    }
    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    priv fun _at(_ set: Set, _ index: UInt256): UInt256 {
        return set._values[index]
    }

    priv fun _values(_ set: Set): [UInt256] {
        return set._values
    }

   

    //UFix64 set
    //Useful for keeping a set of prices in FLOW or FUSD
    pub struct UFix64Set  {
        pub var _inner: Set

        init(){ self._inner = Set()}

         //Arithmetic
        priv fun _pow(_ base: UFix64, _ exponent: UFix64): UFix64 {
            var num = base
            var i = 0.0
            while i < exponent {
                num = num * num
                i = i + 1.0
            }
            return num
        }

        /**
        * @dev Add a value to a set. O(1).
        *
        * Returns the set with the added element and true if the value was added to the set,
        * that is if it was not already present, in which case it returns the same set and false
        */
        pub fun add(_ value: UFix64): Bool {
            var uint256Val = value * (self._pow(10.0, 8.0)) //Max factor for UFix64 = 100000000
            var setReturn: SetReturn = EnumerableSet._add(self._inner, UInt256(uint256Val))
            self._inner = setReturn.set
            return setReturn.present
        }

        /**
        * @dev Removes a value from a set. O(1).
        *
        * Returns true if the value was removed from the set, that is if it was
        * present.
        */
        pub fun remove(_ value: UFix64): Bool {
            var uint256Val = value * (self._pow(10.0, 8.0)) //Max factor for UFix64 = 100000000
            var setReturn: SetReturn = EnumerableSet._remove(self._inner, UInt256(uint256Val))
            self._inner = setReturn.set
            return setReturn.present
        }

        /**
        * @dev Returns true if the value is in the set. O(1).
        */
        pub fun contains(_ value: UFix64): Bool {
            var uint256Val = value * (self._pow(10.0, 8.0)) //Max factor for UFix64 = 100000000
            return EnumerableSet._contains(self._inner, UInt256(uint256Val));
        }

        /**
        * @dev Returns the number of values in the set. O(1).
        */
        pub fun length(): UInt256 {
            return EnumerableSet._length(self._inner)
        }

        /**
        * @dev Returns the value stored at position `index` in the set. O(1).
        *
        * Note that there are no guarantees on the ordering of values inside the
        * array, and it may change when more values are added or removed.
        *
        * Requirements:
        *
        * - `index` must be strictly less than {length}.
        */
        pub fun at(_ index: UInt256): UFix64 {
            var ufix64Val = UFix64(EnumerableSet._at(self._inner, index)) / self._pow(10.0, 8.0)
            return ufix64Val
        }

        /**
        * @dev Return the entire set in an array O(n)
        */
        pub fun values(): [UFix64] {
            var innerValues = EnumerableSet._values(self._inner)
            var ufixValues: [UFix64] = []
            for val in innerValues {
                var ufix64Val = UFix64(val) / self._pow(10.0, 8.0)
                ufixValues.append(ufix64Val)
            }
            return ufixValues
        }

    }

    

}
 