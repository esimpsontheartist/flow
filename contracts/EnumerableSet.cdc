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

        /**
        * @dev Add a value to a set. O(1).
        *
        * Returns the set with the added element and true if the value was added to the set,
        * that is if it was not already present, in which case it returns the same set and false
        */
        access(contract) fun _add(_ value: UInt256): Bool {
            if !self._contains(value) {
                self._values.append(value)
                // The value is stored at length-1, but we add 1 to all indexes
                // and use 0 as a sentinel value
                self._indexes[value] = UInt256(self._values.length);
                return true
            } 
            return false
        }

        /**
        * @dev Returns true if the value is in the set. O(1).
        */
        access(contract) fun _contains(_ value: UInt256): Bool {
            return self._indexes[value] != 0
        }

         /**
        * @dev Removes a value from a set. O(1).
        *
        * Returns the set with the removed element and true if the value was removed from the set,
        * that is if it was not already present, in which case it returns the same set and false
        */
        access(contract) fun _remove(_ value: UInt256): Bool {
            if self._indexes[value] == nil {
                return false
            }
            var valueIndex = self._indexes[value]!

            if self._contains(value) {
                // Equivalent to contains(set, value)
                // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
                // the array, and then remove the last element (sometimes called as 'swap and pop').
                // This modifies the order of the array, as noted in {at}.

                var toDeleteIndex = valueIndex - 1;
                var lastIndex = UInt256(self._values.length) - 1

                if lastIndex != toDeleteIndex {
                    var lastvalue = self._values[lastIndex]

                    // Move the last value to the index where the value to delete is
                    self._values[toDeleteIndex] = lastvalue;
                    // Update the index for the moved value
                    self._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
                }

                // Delete the slot where the moved value was stored
                self._values.removeLast();

                // Delete the index for the deleted slot
                self._indexes.remove(key: value)

                return true
            }

            return false
        }

        /**
        * @dev Returns the number of values on the set. O(1).
        */
        access(contract) fun _length(): UInt256 {
            return UInt256(self._values.length)
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
        access(contract) fun _at( _ index: UInt256): UInt256 {
            return self._values[index]
        }

        access(contract) fun values(): [UInt256] {
            return self._values
        }

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
            return self._inner._add(UInt256(uint256Val))
        }

        /**
        * @dev Removes a value from a set. O(1).
        *
        * Returns true if the value was removed from the set, that is if it was
        * present.
        */
        pub fun remove(_ value: UFix64): Bool {
            var uint256Val = value * (self._pow(10.0, 8.0)) //Max factor for UFix64 = 100000000
            return self._inner._remove(UInt256(uint256Val))
        }

        /**
        * @dev Returns true if the value is in the set. O(1).
        */
        pub fun contains(_ value: UFix64): Bool {
            var uint256Val = value * (self._pow(10.0, 8.0)) //Max factor for UFix64 = 100000000
            return self._inner._contains(UInt256(uint256Val));
        }

        /**
        * @dev Returns the number of values in the set. O(1).
        */
        pub fun length(): UInt256 {
            return self._inner._length()
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
            var ufix64Val = UFix64(self._inner._at(index)) / self._pow(10.0, 8.0)
            return ufix64Val
        }

        /**
        * @dev Return the entire set in an array O(n)
        */
        pub fun values(): [UFix64] {
            var innerValues = self._inner.values()
            var ufixValues: [UFix64] = []
            for val in innerValues {
                var ufix64Val = UFix64(val) / self._pow(10.0, 8.0)
                ufixValues.append(ufix64Val)
            }
            return ufixValues
        }

    }

    //UFix64 set
    //Useful for keeping a set of prices in FLOW or FUSD
    pub struct UInt64Set  {
        pub var _inner: Set

        init(){ self._inner = Set()}

        /**
        * @dev Add a value to a set. O(1).
        *
        * Returns the set with the added element and true if the value was added to the set,
        * that is if it was not already present, in which case it returns the same set and false
        */
        pub fun add(_ value: UInt64): Bool {
            return self._inner._add(UInt256(value))
        }

        /**
        * @dev Removes a value from a set. O(1).
        *
        * Returns true if the value was removed from the set, that is if it was
        * present.
        */
        pub fun remove(_ value: UInt64): Bool {
            return self._inner._remove(UInt256(value))
        }

        /**
        * @dev Returns true if the value is in the set. O(1).
        */
        pub fun contains(_ value: UFix64): Bool {
            return self._inner._contains(UInt256(value));
        }

        /**
        * @dev Returns the number of values in the set. O(1).
        */
        pub fun length(): UInt256 {
            return self._inner._length()
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
        pub fun at(_ index: UInt256): UInt64 {
            var uint64Val = UInt64(self._inner._at(index))
            return uint64Val
        }

        /**
        * @dev Return the entire set in an array O(n)
        */
        pub fun values(): [UInt64] {
            var innerValues = self._inner.values()
            var uint64Values: [UInt64] = []
            for val in innerValues {
                var uint64Val = UInt64(val) 
                uint64Values.append(uint64Val)
            }
            return uint64Values
        }

    }

    

}
 