*** Settings ***
Documentation       Template robot main suite.

Library             RPA.Browser.Selenium    auto_close=${FALSE}
Library             RPA.HTTP
Library             RPA.Excel.Files
Library             RPA.PDF
Library             RPA.Tables
Library             RPA.Archive
Library             RPA.Dialogs
Library             RPA.Robocloud.Secrets
Library             OperatingSystem
Library             RPA.RobotLogListener


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Directory Cleanup
    Get The Program Author Name From Our Vault
    ${username}=    Get The User Name
    Open the robot order website
    ${orders}=    Get orders
    FOR    ${row}    IN    @{orders}
        Close the annoying modal
        Fill the form    ${row}
        Preview the robot
        Submit the order
        ${resultOfScreenshot}=    Take a screenshot of the robot
        IF    ${resultOfScreenshot} == "webpage not loaded correctly"
            Log    "webpage not loaded correctly"
        ELSE
            ${orderid}    ${img_filename}=    Take a screenshot of the robot
            ${pdf_filename}=    Store the receipt as a PDF file    ORDER_NUMBER=${order_id}
            Embed the robot screenshot to the receipt PDF file    IMG_FILE=${img_filename}    PDF_FILE=${pdf_filename}
            Go to order another robot
        END
    END
    Create a ZIP file of the receipts
    Log Out And Close The Browser
    Display the success dialog    USER_NAME=${username}


*** Keywords ***
# Open the application
Open the robot order website
    Open Available Browser    https://robotsparebinindustries.com/#/robot-order

Directory Cleanup
    Create Directory    ${CURDIR}${/}image_files
    Create Directory    ${CURDIR}${/}pdf_files

    Empty Directory    ${CURDIR}${/}image_files
    Empty Directory    ${CURDIR}${/}pdf_files

Get orders
    Download    https://robotsparebinindustries.com/orders.csv    overwrite=True
    ${table}=    Read table from CSV    path=${CURDIR}${/}orders.csv
    RETURN    ${table}

Close the annoying modal
    # Define local variables for the UI elements
    Set Local Variable    ${btn_yep}    //*[@id="root"]/div/div[2]/div/div/div/div/div/button[2]
    TRY
        Wait And Click Button    ${btn_yep}
    EXCEPT
        Log    "Popup did not appear"
    END

Fill the form
    [Arguments]    ${myrow}
# MAKING SURE THAT APPLICATION LOAD IS COMPLETE
    Wait Until Page Contains Element    id:head
    Select From List By Value    head    ${myrow}[Head]
    Wait Until Page Contains Element    body
    Select Radio Button    body    ${myrow}[Body]
    Wait Until Element Is Enabled    address
    Input Text    address    ${myrow}[Address]
    Wait Until Element Is Enabled    xpath://html/body/div/div/div[1]/div/div[1]/form/div[3]/input
    Input Text    xpath://html/body/div/div/div[1]/div/div[1]/form/div[3]/input    ${myrow}[Legs]

Preview the robot
    Click Button    preview

Submit the order
    Sleep    1sec
    Wait Until Page Contains Element    id:order
    Click button    order
    TRY
        Click button    order
    EXCEPT
        Log    Warning : First time click worked.
    END
    Mute Run On Failure    Page Should Contain Element
    TRY
        Page Should Contain Element    receipt
    EXCEPT
        Log    Warning :webpage not loaded correctly
    END

Take a screenshot of the robot
    # Wait for page to load
    TRY
        Wait Until Element Is Visible    xpath://html/body/div/div/div[1]/div/div[1]/div/div/p[1]
        Wait Until Element Is Visible    robot-preview-image

        #get the order ID
        ${orderid}=    Get Text    //*[@id="receipt"]/p[1]

        # Create the File Name
        Set Local Variable    ${fully_qualified_img_filename}    ${CURDIR}${/}image_files${/}${orderid}.PNG

        #Set delay or 1 second
        Sleep    1sec
        Log To Console    Capturing Screenshot to ${fully_qualified_img_filename}
        Capture Element Screenshot    robot-preview-image    ${fully_qualified_img_filename}
        RETURN    ${orderid}    ${fully_qualified_img_filename}
    EXCEPT
        Log    Warning :webpage not loaded correctly
        RETURN    "webpage not loaded correctly"
    END

Go to order another robot
    Click Button    order-another
    TRY
        Click Button    order-another
    EXCEPT
        Log    Warning : First time click worked.
    END

Log Out And Close The Browser
    Close Browser

Create a Zip File of the Receipts
    Archive Folder With ZIP
    ...    ${CURDIR}${/}pdf_files
    ...    ${CURDIR}${/}output${/}pdf_archive.zip
    ...    recursive=True
    ...    include=*.pdf

Store the receipt as a PDF file
    [Arguments]    ${ORDER_NUMBER}

    Wait Until Element Is Visible    receipt
    Log To Console    Printing ${ORDER_NUMBER}
    ${order_receipt_html}=    Get Element Attribute    receipt    outerHTML

    Set Local Variable    ${fully_qualified_pdf_filename}    ${CURDIR}${/}pdf_files${/}${ORDER_NUMBER}.pdf

    Html To Pdf    content=${order_receipt_html}    output_path=${fully_qualified_pdf_filename}
    RETURN    ${fully_qualified_pdf_filename}

Embed the robot screenshot to the receipt PDF file
    [Arguments]    ${IMG_FILE}    ${PDF_FILE}

    Log To Console    Printing Embedding image ${IMG_FILE} in pdf file ${PDF_FILE}

    # Create the list of files that is to be added to the PDF (here, it is just one file)
    @{myfiles}=    Create List    ${IMG_FILE}:x=0,y=0

    # Add the files to the PDF
    Add Files To PDF    ${myfiles}    ${PDF_FILE}    ${True}

Get The Program Author Name From Our Vault
    Log To Console    Getting Secret from our Vault
    ${secret}=    Get Secret    mysecrets
    Log    ${secret}[whowrotethis] wrote this program for you    console=yes

Get The User Name
    Add heading    I am your RoboCorp Order Genie
    Add text input    myname    label=What is thy name, oh sire?    placeholder=Give me some input here
    ${result}=    Run dialog
    RETURN    ${result.myname}

Display the success dialog
    [Arguments]    ${USER_NAME}
    Add icon    Success
    Add heading    Your orders have been processed
    Add text    Dear ${USER_NAME} - all orders have been processed. Have a nice day!
    Run dialog    title=Success
