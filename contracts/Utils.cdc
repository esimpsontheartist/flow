
pub contract Utils {
        pub fun slice(_ array: [UFix64], _ begin: Integer, _ last: Integer): [UFix64] {
            var arr: [UFix64] = []
            var i = begin
            while i < last {
                arr.append(array[i])
                i = i + 1
            }
            return arr
        }

        pub fun sort(_ array: [UFix64]): [UFix64] {
            //create copy because arguments are constant
            var arr = array
            var length = arr.length
            //base case
            if length < 2 {
                return arr
            }

            //position of the partition
            var currentPosition = 0

            var i = 1
            while i < length {
                if arr[i] <= arr[0] {
                    currentPosition = currentPosition + 1
                    arr[i] <-> arr[currentPosition]
                }
            }

            //swap
            arr[0] <-> arr[currentPosition]

            var left: [UFix64] = self.sort(self.slice(arr, 0, currentPosition))
            var right: [UFix64] = self.sort(self.slice(arr, currentPosition + 1, length))

            //mergin the arrays
            arr = left
            arr.append(arr[currentPosition])
            arr.appendAll(right)
            return arr
        }  
}