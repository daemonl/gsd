To consider:
Plural names?
'secondary paths' with translation
or returning paths rather than primary keys. (Overhead = bad, convenience = good)

Setting a member of a null owned object creates the object?

Able to null owned objects?

Update is partial, this is not nosql. To null it, set it to null
patient[1].name.first = 'john' vs patient[1].name = {first: 'john'}
after patient[1].name = {first: 'john'}, will patient[1].name.last still be 'smith'


PATH
====

Root Collection
---------------
    patient = an array of patient objects
    patient[55] = {age: 55, gender: 'M' ...} - the default fields
    patient[55].age = 55
    patient[55].[age] = {age: 55}
    patient[55].[age,gender] = {age: 55, gender: 'M'}
    patient[55].* = Everything in and belonging to the patient
    patient[55].(quicklist) = Everything in the mask labelled 'quicklist'
    patient[55].[(quicklist),gender] = The quicklist mask, and the gender (merged)
    patient[55].[(quicklist),(medicare)] = the two masks, merged
    patient[55].[name.first, name.last]

    patient.* = Array accessor of the complete patient table and all related entities.
    patient.(quicklist) = Array accessor of the quicklist components of all patients


Best practice in a client app is to request the whole object and filter there, chances are if there is a request for the
patient's first name there will also be cause to get the second name. Excepting lists. That's the stuff of the client app.

Setting must be explicit:

    set('patient[1]', {gender: 'M', name: {first: 'john'}})

And updates are merged with the existing object. In the above case, John's last name is still 'Smith'.
Set data to null when you want to delete it.

    set('patient[1]', {gender: 'M', name: {first: 'john', last: null}})

Searching

    get('patient.*')
    get('patient.(quicklist)', [{field: 'patient.name.first', compare: 'LIKE', with: '%john%']})
    get('patient.(quicklist)', [{field: 'patient.(quicksearch)', compare: 'LIKE', with: '%john%'}])

The single query object is an OR, multiple queries are AND.

   get('patient', [
     {field: 'patient.name.[first,last]', compare: 'LIKE', with: '%john%'},
     {field: 'patient.gender', with: 'M'}
     ]

    SELECT patient... FROM patient LEFT JOIN name ON name.id = patient.name WHERE
      (name.first LIKE '%john%' OR name.last LIKE '%john%')
      AND
      patient.gender = 'M'

compare: '=' is the default




Owned Object
------------
    patient[55].name = {first: 'John', last: 'Smith'}
    patient[55] = {... name: {first: ...}}
    patient[55].name.first = 'John'

the PK is transparent.
Optional owned could be null.

Owned Collection
----------------

    patient[55].phones = [{id: 644, type: 'mobile', number: '12345'}, {id: 645, type: 'home', number: '5678'}]
    patient[55].phone[644] = {id: 644, type...}
    patient[55].phone[644].type = 'mobile'
    phone[644] = ERROR

 - Phones don't need / have security, they inherit the security of their owner.
If this isn't appropriate for some of your data, create it as a related object/collection.

Related Object
--------------

    patient[55].mainDoctor = 533
    doctor[533] = {...}
    patient[55].mainDoctor.name = ERROR

- Use the reference. There is and should be only one way to access to avoid complexity.
Each data field has only one path.

Related Collection
------------------

    patient[55].invoice = [155, 188, 300]
    invoice[155] = {...}
    patient[55].invoice[155] = ERROR (as above)


SECURITY
========

1: If logged in then has access
2: Role based
3: Root collection objects owned by single group
4: Root collection objects have multiple groups (ACL)


Security Methods for root collections
-------------------------------------
Single reference: groupId on all root objects.
Each user belongs to one or more group in certain roles: Admin, User etc

    user[5].access = {10: 'admin', 11: 'admin', 12: 'user'}
    user[5].access[10] = 'admin'
    user[5].access[9] = null

objects then have their own permission schema:
field: the object has a field called groupId
