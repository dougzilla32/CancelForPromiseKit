//
//  ListOfItemsTest.swift
//  CPKCoreTests
//
//  Created by Doug Stein on 5/26/18.
//

import XCTest
import PromiseKit
import CancelForPromiseKit

var cancelItemSet = Set<Int>()
var cancelItemList = [Int]()

class ListOfItemsTest: XCTestCase {
    class ListOfItems {
        var items: [Int]
        
        init(items: [Int]) {
            self.items = items
        }
    }

    func testRemoveItems() {
        print("")
        for i in [ 1,3,5,7,9,2,4,6,8,0 ] {
            cancelItemSet.insert(i)
            cancelItemList.append(i)
        }
        
        let list = ListOfItems(items: [6,4,2])
        removeItems(list)
        print(cancelItemSet)
        print(cancelItemList)
        print("")

        let list2 = ListOfItems(items: [3,5,8])
        removeItems(list2)
        print(cancelItemSet)
        print(cancelItemList)
        print("")
    }

    func removeItems(_ list: ListOfItems) {
        guard list.items.count != 0 else {
            return
        }
        
        var currentIndex = 1
        // The `list` parameter should match a block of items in the cancelItemList, remove them from the cancelItemList
        // in one operation for efficiency
        if cancelItemSet.remove(list.items[0]) != nil {
            let removeIndex = cancelItemList.index(of: list.items[0])!
            print("removeItems.removeIndex \(removeIndex)")
            while currentIndex < list.items.count {
                let item = list.items[currentIndex]
                if item != cancelItemList[removeIndex + currentIndex] {
                    break
                }
                cancelItemSet.remove(item)
                currentIndex += 1
            }
            cancelItemList.removeSubrange(removeIndex..<(removeIndex+currentIndex))
            print("removeSubrange \(removeIndex..<(removeIndex+currentIndex))")
        }
        
        // Remove whatever falls outside of the block
        if currentIndex < list.items.count {
            print("WHOA! outside of block")
        }
        while currentIndex < list.items.count {
            let item = list.items[currentIndex]
            if cancelItemSet.remove(item) != nil {
                print("removeAt \(cancelItemList.index(of: item)!)")
                cancelItemList.remove(at: cancelItemList.index(of: item)!)
            }
            currentIndex += 1
        }
    }
}
