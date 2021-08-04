/*Copyright (c) 2021, Daniel Appleman

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, 
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation 
and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors 
may be used to endorse or promote products derived from this software without 
specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND 
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF 
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

// This class might be global or have the @namespaceaccessible annotation

public inherited sharing class TriggerDMLSupport {
    
    public static Boolean updatingPendingObjects = false;
    private static Map<String, Map<ID, SObject>> objectsToUpdate = new Map<String, Map<ID, SObject>>();

    // Return a list of updatable SObject records
    public static List<SObject> getUpdatableObjects(String objType, Set<ID> objIds)
    {
        Map<ID, SObject> objMap = objectsToUpdate.get(objType);
        if(objMap==null)
        {
            objMap = new Map<ID, SObject>();
            objectsToUpdate.put(objType, objMap);
        }
        List<SObject> results = new List<SObject>();
        for(ID objId: objIds)
        {
            if(!objMap.containsKey(objId)) objMap.put(objID, objID.getSObjectType().newSObject(objId));
            results.add(objMap.get(objId));
        } 
        return results;
    }

    private static Boolean updatesPending()
    {
        for(String objType: objectsToUpdate.keyset())
        {
            if(objectsToUpdate.get(objType).size()>0) return true;
        }
        return false;
    }

    public static void updatePendingObjects()
    {
        if(!updatingPendingObjects) 
        {
            while(updatesPending())
            {
                for(String objType: objectsToUpdate.keyset())
                {
                    Map<ID, SObject> objectToUpdateMap = objectsToUpdate.get(objType);
                    if(objectToUpdateMap.size()==0) continue;
                    List<SObject> updatingList = objectToUpdateMap.values();
                    objectsToUpdate.put(objType, new Map<ID, SObject>());
                    updatingPendingObjects = true;
                    update updatingList;
                    updatingPendingObjects = false;
                }
            }
        }
    }

}
