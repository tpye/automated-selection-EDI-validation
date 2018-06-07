Attribute VB_Name = "BFM_EDIvalidation"

Private Error_array() As Variant
Private CellAddress As String
Private startCell As Range
Private endCell As Range
Private sumRange As Range
Private NetPaid_Amt As Double
Private ClaimPaid_Amt As Double
Private FeePaid_Amt As Double
Private Payable_Amt As Double
Private num As Integer
Private ClaimNumber As String
Private ws As Worksheet
Private Errors As Boolean
Private myCell_last As Integer
Private testColumn As Integer
Private finalrow As Integer
Private searchRange As Range
Private ErrorCode As String
Private claimColumn As Integer
Private filestring As String
Private fileName As String

Public Sub BFM_EDI_Validator()

Application.ScreenUpdating = False

Call import_XML
If Errors = True Then
    GoTo skipBlock
    Else
    ' nothing
End If

Set ws = ActiveSheet
Set searchRange = ws.UsedRange
testColumn = searchRange.Find(what:="LineNumber", LookAt:=xlWhole).column
claimColumn = searchRange.Find(what:="ACM_ID", LookAt:=xlWhole).column
finalrow = ws.Range("A1048576").End(xlUp).Row
num = 0

Errors = False


Call LineNumberTest

skipBlock:

Application.ScreenUpdating = True


If Errors = True Then
    MsgBox "Procedure is complete. Error Report has been created."
    Else
    directory = "P:\Public\ACM\HSP\BFM\Javelina Response File\"
    ActiveWorkbook.SaveAs fileName:=directory & Name_File()
    Call Make_Outlook_Mail_With_File_Link
    MsgBox "Procedure Complete!"
End If

End Sub

Sub LineNumberTest()
Dim myRange As Range
Dim myCell As Range


Set myRange = ws.Range(Cells(2, testColumn), Cells(finalrow, testColumn))
Set myCell = ws.Cells(2, testColumn)


' log duplicate lineNumber
For Each myCell In myRange
    mycellAddress = myCell.Address
    myCell_last = myCell.Value
    If myCell.Offset(1, 0).Value = myCell_last Then
        CellAddress = myCell.Address
        ClaimNumber = myCell.Offset(0, -(testColumn - claimColumn))
        ErrorCode = "Dublicate LineNumber"
        Call build_Array
        num = num + 1
        Else
        'nothing
    End If
Next myCell

testColumn = searchRange.Find(what:="Charge", LookAt:=xlWhole).column
claimColumn = searchRange.Find(what:="ACM_ID", LookAt:=xlWhole).column
Set myRange = ws.Range(Cells(2, testColumn), Cells(finalrow, testColumn))
Set myCell = ws.Cells(2, testColumn)

' log missing attributes
For Each myCell In myRange
    mycellAddress = myCell.Address
    If myCell.Value = "" Or myCell.Offset(0, 1) = "" Then
        CellAddress = myCell.Address
        ClaimNumber = myCell.Offset(0, -(testColumn - claimColumn))
        ErrorCode = " Charge and/or PayableAmt Attribute(s) are not included"
        Call build_Array
        num = num + 1
        Else
        'nothing
    End If
Next myCell


Call PaidStatus_Test

End Sub


Sub PaidStatus_Test()

Dim myRange As Range
Dim myCell As Range

testColumn = searchRange.Find(what:="ClaimStatus", LookAt:=xlWhole).column
claimColumn = searchRange.Find(what:="ACM_ID", LookAt:=xlWhole).column

Set myRange = ws.Range(Cells(2, testColumn), Cells(finalrow, testColumn))
Set myCell = ws.Cells(2, testColumn)

'log claim with claimstatus paid
For Each myCell In myRange
    mycellAddress = myCell.Address
    If myCell.Value = "PAID" Then
        CellAddress = myCell.Address
        ClaimNumber = myCell.Offset(0, -(testColumn - claimColumn))
        ErrorCode = "ClaimStatus is set to Paid"
        Call build_Array
        num = num + 1
        Else
        'nothing
    End If
Next myCell

Call ClaimAmt_Test

End Sub

Sub ClaimAmt_Test()
Dim myRange As Range
Dim myCell As Range
Dim sumRange As Range
Dim startCell As Integer
Dim endCell As Integer
Dim sumColumn As Integer
Dim ClaimPaidAmt As Double
Dim NetPaidAmt As Double
Dim testNetPaidAmt As Double
Dim testClaimPaidAmt As Double

testColumn = searchRange.Find(what:="LineNumber", LookAt:=xlWhole).column
Set myRange = ws.Range(Cells(2, testColumn), Cells(finalrow, testColumn))
Set myCell = ws.Cells(2, testColumn)
sumColumn = searchRange.Find(what:="PayableAmt", LookAt:=xlWhole).column

' validate claimline sums with claim totals
With Application.WorksheetFunction
For Each myCell In myRange
    If myCell.Value = 1 Then
        NetPaidAmt = Format(Trim(myCell.Offset(0, -3).Value), "Currency")
        Claimstatus = Trim(myCell.Offset(0, -4).Value)
        ClaimPaidAmt = Format(Trim(myCell.Offset(0, -2).Value), "Currency")
        feePaidAmt = Format(Trim(myCell.Offset(0, -1).Value), "Currency")
        startCell = myCell.Row
    ElseIf myCell.Value = 999 Then
        endCell = myCell.Row
        Set NetPaidAmtRange = ws.Range(Cells(startCell, sumColumn), Cells(endCell, sumColumn))
        Set ClaimPaidAmtRange = ws.Range(Cells(startCell, sumColumn), Cells(endCell - 1, sumColumn))
        testNetPaidAmt = Format(.Sum(NetPaidAmtRange), "Currency")
        testClaimPaidAmt = Format(.Sum(ClaimPaidAmtRange), "Currency")
            If Claimstatus = "PEND" Or Claimstatus = "EXC" Then
                'nothing
                Else
                    If testNetPaidAmt = NetPaidAmt And testClaimPaidAmt = ClaimPaidAmt Then
                    'nothing
                    Else
                    CellAddress = ws.Cells(startCell, sumColumn).Address
                    ClaimNumber = ws.Cells(startCell, sumColumn).Offset(0, -9)
                    ErrorCode = "Claim Amounts do not match. NetPaidAmt=" & NetPaidAmt & " Sum of payable & fee=" & testNetPaidAmt & " ClaimPaidAmt=" & ClaimPaidAmt & " Sum of payable=" & testClaimPaidAmt
                    Call build_Array
                    num = num + 1
                End If
            End If
    Else
        'nothing
    End If
Next myCell
End With

On Error Resume Next
Err.Clear
t = LBound(Error_array)
If Err.number = 0 Then
    Errors = True
    Call Error_Reporting
    Else
    Call Procedure_Reporting
End If

End Sub

Sub Error_Reporting()
Dim num As Integer
Dim wb As Workbook


U_Limit = UBound(Error_array, 1)
U_Limit2 = UBound(Error_array, 2)
Set wb = Workbooks.Add

With wb.Sheets(1)
    .Cells(1, 1).Value = "ClaimNumber"
    .Cells(1, 2).Value = "CellAddress"
    .Cells(1, 3).Value = "ErrorCode"
End With

For i = 0 To U_Limit
    For j = 0 To U_Limit2
    wb.Sheets(1).Cells(j + 2, i + 1).Value = Error_array(i, j)
    Next j
Next i
    Erase Error_array
    
If Month(Now()) < 10 Then
    monthstring = "0" & Month(Now())
    Else
    monthstring = Month(Now())
End If

If Day(Now()) < 10 Then
    daystring = "0" & Day(Now())
    Else
    daystring = Day(Now())
End If

If Hour(Now()) < 10 Then
    hourstring = "0" & Hour(Now())
    Else
    hourtring = Hour(Now())
End If

If Minute(Now()) < 10 Then
    MinuteString = "0" & Minute(Now())
    Else
    MinuteString = Minute(Now())
End If

If Second(Now()) < 10 Then
    SecondString = "0" & Second(Now())
    Else
    SecondString = Second(Now())
End If

filestring = Year(Now) & monthstring & daystring & "_" & hourstring & MinuteString & SecondString & "_BFM_EDI_ErrorReport.xlsx"


wb.SaveAs fileName:="P:\CSG\BusApps\Common\Trevorp\BFM\BFM_ClaimsFiles\" & filestring


    
Call Procedure_Reporting

End Sub

Sub Procedure_Reporting()
Dim userName As String
Dim procedureResult As String
Dim dateTimeStamp As Date
Dim wbProcedureLog As Workbook
Dim finalrow As Integer
Dim wks As Worksheet

Set wbProcedureLog = Workbooks.Open(fileName:="P:\CSG\BusApps\Common\Trevorp\BFM\BFM_ClaimsFiles\BFM_Error_Report.xlsx")
Set wks = wbProcedureLog.Worksheets("Log")

userName = Application.userName
dateTimeStamp = Now()

If Errors = True Then
    procedureResult = "File '" & fileName & "' contains errors. See " & "'" & filestring & "'" & " error report for error details"
    Else
    procedureResult = "Review of '" & fileName & "' is complete and no errors have been identified."
End If

finalrow = wks.Cells(Rows.Count, 1).End(xlUp).Row

With wks
    .Cells(finalrow + 1, 1).Value = dateTimeStamp
    .Cells(finalrow + 1, 2).Value = userName
    .Cells(finalrow + 1, 3).Value = procedureResult
    .Columns(3).AutoFit
End With
    
    
With wbProcedureLog
    .Save
    .Close
End With
    
End Sub

Sub build_Array()


ReDim Preserve Error_array(2, num)


For i = 0 To 2
    If i = 1 Then
        Error_array(i, num) = Array(CellAddress)
    ElseIf i = 2 Then
        Error_array(i, num) = Array(ErrorCode)
    Else
        Error_array(i, num) = Array(ClaimNumber)
    End If
Next i


End Sub

Sub import_XML()
'
' import_XML Macro
'

'

yearReport = Year(Now())
If Month(Now() - t) < 10 Then
    monthReport = 0 & Month(Now() - 1)
    Else
    monthReport = Month(Now() - 1)
End If

If Weekday(Now(), 1) = 2 Then
    t = 3
    Else
    t = 1
End If

'control friday
If Day(Now() - t) < 10 Then
    dayReport = 0 & Day(Now() - t)
    Else
    dayReport = Day(Now() - t)
End If

directory = "\\cawinw16\bfm\Production\Inbound\"
fileName = Dir(directory & yearReport & monthReport & dayReport & "_*_BFM-ACM.xml")

If fileName = "" Then
    MsgBox "File is not found"
        CellAddress = "Not Applicable"
        ClaimNumber = "Not Applicable"
        ErrorCode = "File not Found"
        Call build_Array
        Errors = True
        
        Call Error_Reporting
        Call Make_Outlook_Mail_With_NoFile
    Exit Sub
    Else
    'Nothing
End If
    Errors = False
    
    ActiveWorkbook.XmlImport URL:=directory & fileName _
        , ImportMap:=Nothing, Overwrite:=True, Destination:=Range("$A$1")

End Sub

Sub Make_Outlook_Mail_With_File_Link()

    Dim OutApp As Object
    Dim OutMail As Object
    Dim strbody As String

    If ActiveWorkbook.Path <> "" Then
        Set OutApp = CreateObject("Outlook.Application")
        Set OutMail = OutApp.CreateItem(0)

        strbody = "<font size=""3"" face=""Calibri"">" & _
                  "Hi,<br/><br/>" & _
                  "I have attached the latest  BF&amp;M response file. Let me know if you have any questions."

        On Error Resume Next
        With OutMail
            .display
            .To = "Cgulisano@active-care.ca"
            .CC = "mpaquette@active-care.ca; jterry@active-care.ca; jrenon@active-care.ca"
            .BCC = ""
            .Subject = "BFM Response File [" & fileName & "]"
            .HTMLbody = strbody & "<br/>" & .HTMLbody
            .Attachments.Add ActiveWorkbook.fullName
            .display   'or use .Send
        End With
        On Error GoTo 0

        Set OutMail = Nothing
        Set OutApp = Nothing
    Else
        MsgBox "The ActiveWorkbook does not have a path, Save the file first."
    End If
End Sub



Public Function Name_File()

If Weekday(Now(), 1) = 2 Then
    t = 3
    Else
    t = 1
End If

yearReport = Year(Now() - t)

monthReport = MonthName(Month(Now() - t), True)


'control friday
If Day(Now() - t) < 10 Then
    dayReport = 0 & Day(Now() - t)
    Else
    dayReport = Day(Now() - t)
End If


Name_File = monthReport & "_" & dayReport & "_" & yearReport & "_Response_file.xlsx"


End Function


Sub Make_Outlook_Mail_With_NoFile()

    Dim OutApp As Object
    Dim OutMail As Object
    Dim strbody As String

    If ActiveWorkbook.Path <> "" Then
        Set OutApp = CreateObject("Outlook.Application")
        Set OutMail = OutApp.CreateItem(0)

        strbody = "<font size=""3"" face=""Calibri"">" & _
                  "Hi,<br><br>" & _
                  "No  BF&amp;M response file today. Let me know if you have any questions."

        On Error Resume Next
        With OutMail
            .display
            .To = "Cgulisano@active-care.ca"
            .CC = "mpaquette@active-care.ca; jterry@active-care.ca; jrenon@active-care.ca"
            .BCC = ""
            .Subject = "No BFM Response File"
            .HTMLbody = strbody & "<br/>" & .HTMLbody
            .display   'or use .Send
        End With
        On Error GoTo 0

        Set OutMail = Nothing
        Set OutApp = Nothing
    Else
        MsgBox "The ActiveWorkbook does not have a path, Save the file first."
    End If
End Sub

