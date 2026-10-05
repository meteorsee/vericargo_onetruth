param(
    [string]$OutputName = "VeriCargo_OneTruth_Prototype_Deck.pptx",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Rgb([int]$r, [int]$g, [int]$b) {
    return $r + (256 * $g) + (65536 * $b)
}

$C = @{
    Navy      = (Rgb 5 27 55)
    Navy2     = (Rgb 8 43 77)
    Cyan      = (Rgb 38 183 237)
    Blue      = (Rgb 33 120 246)
    Teal      = (Rgb 31 190 177)
    Green     = (Rgb 42 196 140)
    Amber     = (Rgb 245 166 35)
    Red       = (Rgb 239 83 98)
    Purple    = (Rgb 124 90 235)
    Ink       = (Rgb 25 35 45)
    Muted     = (Rgb 87 103 119)
    Pale      = (Rgb 235 246 252)
    PaleBlue  = (Rgb 224 239 255)
    PaleGreen = (Rgb 226 248 239)
    PaleAmber = (Rgb 255 244 220)
    PaleRed   = (Rgb 255 232 235)
    White     = (Rgb 255 255 255)
    LightGray = (Rgb 235 239 243)
}

function Add-Text {
    param(
        $Slide,
        [string]$Text,
        [double]$Left,
        [double]$Top,
        [double]$Width,
        [double]$Height,
        [double]$Size = 18,
        [int]$Color = $C.Ink,
        [bool]$Bold = $false,
        [int]$Align = 1,
        [string]$Font = "Aptos"
    )

    $shape = $Slide.Shapes.AddTextbox(1, $Left, $Top, $Width, $Height)
    $shape.TextFrame.WordWrap = -1
    $shape.TextFrame.MarginLeft = 0
    $shape.TextFrame.MarginRight = 0
    $shape.TextFrame.MarginTop = 0
    $shape.TextFrame.MarginBottom = 0
    $range = $shape.TextFrame.TextRange
    $range.Text = $Text
    $range.Font.Name = $Font
    $range.Font.Size = $Size
    $range.Font.Bold = $(if ($Bold) { -1 } else { 0 })
    $range.Font.Color.RGB = $Color
    $range.ParagraphFormat.Alignment = $Align
    return $shape
}

function Add-RoundedBox {
    param(
        $Slide,
        [double]$Left,
        [double]$Top,
        [double]$Width,
        [double]$Height,
        [int]$Fill,
        [int]$Line = $C.Cyan,
        [double]$Transparency = 0
    )

    $shape = $Slide.Shapes.AddShape(5, $Left, $Top, $Width, $Height)
    $shape.Fill.ForeColor.RGB = $Fill
    $shape.Fill.Transparency = $Transparency
    $shape.Line.ForeColor.RGB = $Line
    $shape.Line.Weight = 1.25
    return $shape
}

function Add-Card {
    param(
        $Slide,
        [string]$Title,
        [string]$Body,
        [double]$Left,
        [double]$Top,
        [double]$Width,
        [double]$Height,
        [int]$Accent,
        [int]$Fill = $C.White,
        [double]$TitleSize = 16,
        [double]$BodySize = 11.5
    )

    Add-RoundedBox $Slide $Left $Top $Width $Height $Fill $Accent | Out-Null
    $bar = $Slide.Shapes.AddShape(1, $Left, $Top, 6, $Height)
    $bar.Fill.ForeColor.RGB = $Accent
    $bar.Line.Visible = 0
    Add-Text $Slide $Title ($Left + 15) ($Top + 9) ($Width - 25) 23 $TitleSize $Accent $true | Out-Null
    Add-Text $Slide $Body ($Left + 15) ($Top + 36) ($Width - 25) ($Height - 44) $BodySize $C.Ink $false | Out-Null
}

function Add-Title {
    param($Slide, [string]$Title, [string]$Kicker)
    Add-Text $Slide $Kicker 32 47 650 14 9.5 $C.Blue $true | Out-Null
    Add-Text $Slide $Title 32 62 650 30 24 $C.Navy $true | Out-Null
    $line = $Slide.Shapes.AddLine(32, 96, 688, 96)
    $line.Line.ForeColor.RGB = $C.Cyan
    $line.Line.Weight = 2
}

function Add-Footer {
    param($Slide, [int]$Number, [string]$Label = "VeriCargo OneTruth")
    Add-Text $Slide $Label 32 389 250 10 7.5 $C.Muted $false | Out-Null
    Add-Text $Slide ("{0:D2}" -f $Number) 660 388 28 11 8 $C.Blue $true 2 | Out-Null
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$template = Join-Path $repoRoot "Prototype Submission Template _ CoCo CLI Hackathon GCC Edition.pptx"
$architecture = Join-Path $repoRoot "docs\vericargo-onetruth-architecture-4k.png"
$output = Join-Path $repoRoot $OutputName

if (-not (Test-Path -LiteralPath $template)) {
    throw "Template not found: $template"
}
if (-not (Test-Path -LiteralPath $architecture)) {
    throw "Architecture image not found: $architecture"
}
if ((Test-Path -LiteralPath $output) -and -not $Force) {
    throw "Output already exists. Use -Force to rebuild: $output"
}
if (Test-Path -LiteralPath $output) {
    Remove-Item -LiteralPath $output
}

Copy-Item -LiteralPath $template -Destination $output

$app = New-Object -ComObject PowerPoint.Application
try {
    $presentation = $app.Presentations.Open($output, $false, $false, $false)
    try {
        # Build six clean branded content slides from the supplied blank template slide.
        $blankTemplate = $presentation.Slides.Item(3)
        1..6 | ForEach-Object {
            $copy = $blankTemplate.Duplicate().Item(1)
            $copy.MoveTo($presentation.Slides.Count - 1)
        }

        # Remove the template instruction and placeholder content slides in reverse order.
        foreach ($index in @(5, 4, 3, 2)) {
            $presentation.Slides.Item($index).Delete()
        }

        # Slide 1 - cover.
        $slide = $presentation.Slides.Item(1)
        $coverTexts = @($slide.Shapes | Where-Object { $_.HasTextFrame -and $_.TextFrame.HasText })
        foreach ($shape in $coverTexts) { $shape.Delete() }

        Add-Text $slide "VERICARGO ONETRUTH" 36 246 640 34 27 $C.Navy $true | Out-Null
        Add-Text $slide "Governed Supply Chain Ontology and Exception Copilot" 36 282 640 24 16 $C.Blue $true | Out-Null
        Add-Text $slide "One shipment. Two destinations. One governed truth." 36 311 640 20 14 $C.Ink $false | Out-Null
        Add-Text $slide "Challenge: Supply Chain Ontology and Governed Conversational Analytics" 36 343 640 15 9.5 $C.Muted $true | Out-Null
        Add-Text $slide "Team: VeriCargo   |   Team lead: [ADD NAME]   |   Team size: [ADD NUMBER]" 36 365 640 14 9 $C.Muted $false | Out-Null

        # Slide 2 - problem and users.
        $slide = $presentation.Slides.Item(2)
        Add-Title $slide "Fragmented truth blocks timely action" "01 | BUSINESS PROBLEM"
        Add-Text $slide "ERP says delivered. The Shipping Instruction says Vietnam. The Draft Bill of Lading says Thailand. Which version should the business trust?" 40 108 640 37 15.5 $C.Navy $true 2 | Out-Null

        Add-Card $slide "FRAGMENTED SOURCES" "ERP, logistics, inventory, cost and shipping documents sit in separate systems with inconsistent identifiers." 38 158 201 100 $C.Cyan $C.Pale 14 10.5
        Add-Card $slide "INCONSISTENT METRICS" "Operations, procurement and planning can receive different answers for the same delivery-performance question." 259 158 201 100 $C.Purple (Rgb 242 238 255) 14 10.5
        Add-Card $slide "UNSAFE EXCEPTIONS" "Missing, unreadable or ambiguous evidence is often guessed, ignored or handled through untracked manual follow-up." 480 158 201 100 $C.Red $C.PaleRed 14 10.5

        Add-Text $slide "TARGET USERS" 40 277 110 14 9.5 $C.Blue $true | Out-Null
        Add-Text $slide "Logistics control tower   |   Procurement   |   Planning   |   Document operations" 145 275 535 18 12 $C.Ink $true | Out-Null
        Add-RoundedBox $slide 38 307 643 58 $C.Navy $C.Navy | Out-Null
        Add-Text $slide "ONE GOVERNED ROUTE" 55 319 135 13 9 $C.Cyan $true | Out-Null
        Add-Text $slide "Detect contradiction  ->  preserve evidence  ->  explain with governed AI  ->  human-confirm action  ->  audit outcome" 55 337 608 19 12.5 $C.White $true 2 | Out-Null
        Add-Footer $slide 2

        # Slide 3 - architecture.
        $slide = $presentation.Slides.Item(3)
        Add-Title $slide "Connected evidence-to-action architecture" "02 | SNOWFLAKE-NATIVE SYSTEM DESIGN"
        $picture = $slide.Shapes.AddPicture($architecture, 0, -1, 144, 103, 432, 270)
        $picture.LockAspectRatio = -1
        Add-Text $slide "CoCo builds and verifies the solution; Snowflake runs the governed production workflow." 87 375 546 11 8.8 $C.Muted $true 2 | Out-Null
        Add-Footer $slide 3

        # Slide 4 - governed metric consistency.
        $slide = $presentation.Slides.Item(4)
        Add-Title $slide "One metric, three personas, one answer" "03 | GOVERNED CONVERSATIONAL ANALYTICS"
        Add-Card $slide "OPERATIONS" '"What is our on-time delivery rate for completed shipments?"' 38 115 201 119 $C.Cyan $C.Pale 14 11.5
        Add-Card $slide "PROCUREMENT" '"What is supplier delivery compliance against promised dates?"' 259 115 201 119 $C.Purple (Rgb 242 238 255) 14 11.5
        Add-Card $slide "PLANNING" '"What percentage of delivered shipments arrived on or before promise?"' 480 115 201 119 $C.Teal $C.PaleGreen 14 11.5

        Add-RoundedBox $slide 107 252 506 74 $C.Navy $C.Cyan | Out-Null
        Add-Text $slide "60.0%" 128 263 120 35 31 $C.Cyan $true 2 | Out-Null
        Add-Text $slide "3 on time / 5 delivered" 260 265 190 19 15 $C.White $true 2 | Out-Null
        Add-Text $slide "Shipment grain | Same all-delivered window | Same governed definition" 243 291 326 18 10.5 $C.White $false 2 | Out-Null

        Add-Text $slide "Canonical OTD = delivered shipments on or before promise / delivered shipments" 88 340 544 17 11 $C.Ink $true 2 | Out-Null
        Add-Text $slide "Verified by three independent Agent questions; evidence query IDs are retained in COCO_USAGE.md." 88 361 544 14 8.5 $C.Muted $false 2 | Out-Null
        Add-Footer $slide 4

        # Slide 5 - SHP-1002 proof and controlled action.
        $slide = $presentation.Slides.Item(5)
        Add-Title $slide "One shipment. Two destinations. One governed decision." "04 | SHP-1002 END-TO-END PROOF"

        Add-RoundedBox $slide 38 111 322 237 $C.White $C.Red | Out-Null
        Add-Text $slide "CONFLICTING SOURCE EVIDENCE" 55 124 285 17 13 $C.Red $true | Out-Null
        Add-Text $slide "Finding" 56 155 86 14 9 $C.Muted $true | Out-Null
        Add-Text $slide "Shipping Instruction" 145 155 91 14 9 $C.Muted $true 2 | Out-Null
        Add-Text $slide "Draft BL / Actual" 250 155 91 14 9 $C.Muted $true 2 | Out-Null
        $rule = $slide.Shapes.AddLine(55, 173, 342, 173); $rule.Line.ForeColor.RGB = $C.LightGray
        Add-Text $slide "Destination" 56 181 86 17 10.5 $C.Ink $true | Out-Null
        Add-Text $slide "VNSGN" 145 181 91 17 12 $C.Cyan $true 2 | Out-Null
        Add-Text $slide "THLCH" 250 181 91 17 12 $C.Red $true 2 | Out-Null
        Add-Text $slide "Gross weight" 56 213 86 17 10.5 $C.Ink $true | Out-Null
        Add-Text $slide "8,000 kg" 145 213 91 17 12 $C.Cyan $true 2 | Out-Null
        Add-Text $slide "7,800 kg" 250 213 91 17 12 $C.Red $true 2 | Out-Null
        Add-Text $slide "Delivery" 56 245 86 17 10.5 $C.Ink $true | Out-Null
        Add-Text $slide "Promised" 145 245 91 17 11 $C.Cyan $true 2 | Out-Null
        Add-Text $slide "1 day late" 250 245 91 17 12 $C.Red $true 2 | Out-Null
        Add-Text $slide "Sources" 56 279 86 17 10.5 $C.Ink $true | Out-Null
        Add-Text $slide "doc-shp-1002-si.pdf" 145 277 195 15 9 $C.Ink $false 2 | Out-Null
        Add-Text $slide "doc-shp-1002-bl.pdf" 145 296 195 15 9 $C.Ink $false 2 | Out-Null
        Add-Text $slide "Result: two linked governed exceptions" 56 322 286 15 10.5 $C.Red $true 2 | Out-Null

        $steps = @(
            @{ Y = 112; N = "1"; T = "DETECT"; B = "Late delivery + document mismatch"; C = $C.Red },
            @{ Y = 160; N = "2"; T = "EVIDENCE"; B = "Raw, normalized, confidence, filenames"; C = $C.Cyan },
            @{ Y = 208; N = "3"; T = "EXPLAIN"; B = "Agent answer is cited and read only"; C = $C.Purple },
            @{ Y = 256; N = "4"; T = "CONFIRM"; B = "Cancel = 0 writes; Confirm = 1 case"; C = $C.Amber },
            @{ Y = 304; N = "5"; T = "AUDIT"; B = "RC-000201, 2 links, 3 lifecycle events"; C = $C.Green }
        )
        foreach ($step in $steps) {
            Add-RoundedBox $slide 387 $step.Y 294 39 $C.White $step.C | Out-Null
            $circle = $slide.Shapes.AddShape(9, 398, ($step.Y + 7), 24, 24)
            $circle.Fill.ForeColor.RGB = $step.C; $circle.Line.Visible = 0
            Add-Text $slide $step.N 398 ($step.Y + 11) 24 12 9 $C.White $true 2 | Out-Null
            Add-Text $slide $step.T 433 ($step.Y + 6) 78 14 10.5 $step.C $true | Out-Null
            Add-Text $slide $step.B 433 ($step.Y + 20) 232 13 8.7 $C.Ink $false | Out-Null
        }
        Add-Text $slide "Agent proposes. Human confirms. Every mutation is audited." 386 357 295 20 11 $C.Navy $true 2 | Out-Null
        Add-Footer $slide 5

        # Slide 6 - CoCo lifecycle evidence.
        $slide = $presentation.Slides.Item(6)
        Add-Title $slide "CoCo CLI across the complete delivery lifecycle" "05 | REQUIRED TOOLING AND INGENUITY"
        Add-Text $slide "CoCo is the engineering copilot used to plan, build, execute, test and automate the solution - not a runtime dependency." 42 105 636 25 12 $C.Ink $true 2 | Out-Null

        $phases = @(
            @{ X = 35;  W = 126; T = "PLAN"; B = "Ontology, metrics, architecture, guardrails`nSession 4ce0a356..."; C = $C.Cyan },
            @{ X = 168; W = 126; T = "DEVELOP"; B = "SQL/Python review + Korean port alias fix`nSession b46b47a1..."; C = $C.Blue },
            @{ X = 301; W = 126; T = "EXECUTE"; B = "Snowflake objects, Agent and Streamlit`nQuery IDs retained"; C = $C.Purple },
            @{ X = 434; W = 126; T = "TEST + REPAIR"; B = "30/30 local + 28/28 Snowflake`nFailed -> fixed proof"; C = $C.Amber },
            @{ X = 567; W = 118; T = "AUTOMATE"; B = "Governance skill + daily digest Task`nQuery 01c762ea..."; C = $C.Green }
        )
        foreach ($phase in $phases) {
            Add-RoundedBox $slide $phase.X 153 $phase.W 126 $C.White $phase.C | Out-Null
            Add-Text $slide $phase.T ($phase.X + 8) 166 ($phase.W - 16) 17 11.5 $phase.C $true 2 | Out-Null
            Add-Text $slide $phase.B ($phase.X + 10) 199 ($phase.W - 20) 60 9.5 $C.Ink $false 2 | Out-Null
        }
        for ($i = 0; $i -lt 4; $i++) {
            $x1 = 161 + ($i * 133); $x2 = 168 + ($i * 133)
            $line = $slide.Shapes.AddLine($x1, 216, $x2, 216)
            $line.Line.ForeColor.RGB = $C.Cyan
            $line.Line.EndArrowheadStyle = 3
            $line.Line.Weight = 2
        }
        Add-RoundedBox $slide 75 306 570 57 $C.Navy $C.Navy | Out-Null
        Add-Text $slide "FAILED-THEN-FIXED EVIDENCE" 94 318 176 14 9.5 $C.Amber $true | Out-Null
        Add-Text $slide "Busan initially normalized incorrectly -> CoCo repaired SQL alias parity -> all aliases and six document outcomes passed regression." 94 338 532 18 10.2 $C.White $true 2 | Out-Null
        Add-Footer $slide 6

        # Slide 7 - verified MVP, impact and boundaries.
        $slide = $presentation.Slides.Item(7)
        Add-Title $slide "Working MVP, measurable proof, scalable governed core" "06 | IMPACT AND SUBMISSION READINESS"

        $metrics = @(
            @{ X = 38;  V = "30/30"; L = "Local tests"; C = $C.Cyan },
            @{ X = 171; V = "28/28"; L = "Snowflake checks"; C = $C.Blue },
            @{ X = 304; V = "60.0%"; L = "Consistent OTD"; C = $C.Purple },
            @{ X = 437; V = "2"; L = "Linked findings"; C = $C.Red },
            @{ X = 570; V = "3"; L = "Audit events"; C = $C.Green }
        )
        foreach ($metric in $metrics) {
            Add-RoundedBox $slide $metric.X 111 112 77 $C.White $metric.C | Out-Null
            Add-Text $slide $metric.V ($metric.X + 7) 124 98 29 22 $metric.C $true 2 | Out-Null
            Add-Text $slide $metric.L ($metric.X + 7) 158 98 14 9 $C.Ink $true 2 | Out-Null
        }

        Add-Card $slide "WHAT THE MVP PROVES" "- Structured metrics and unstructured documents share one shipment context`n- Failed or ambiguous extraction stays unresolved`n- Unknown IDs, duplicate cases and illegal transitions are blocked`n- Six connected pages preserve investigation context" 38 211 304 132 $C.Teal $C.PaleGreen 14 10.5
        Add-Card $slide "HOW IT EXTENDS" "Replace synthetic ingestion with live ERP, TMS, WMS, carrier, Gmail or extension connectors. The ontology, semantic definitions, evidence model, Agent guardrails, review workflow and audit layer remain reusable." 378 211 304 132 $C.Blue $C.PaleBlue 14 10.5
        Add-Text $slide "Provenance: all submitted business data is synthetic. The prior Chrome extension is disclosed background IP and is outside this runtime." 55 357 610 20 9.3 $C.Muted $true 2 | Out-Null
        Add-Footer $slide 7

        # Slide 8 - branded close.
        $slide = $presentation.Slides.Item(8)
        $panel = $slide.Shapes.AddShape(5, 88, 262, 544, 101)
        $panel.Fill.ForeColor.RGB = $C.Navy
        $panel.Fill.Transparency = 0.16
        $panel.Line.ForeColor.RGB = $C.Cyan
        $panel.Line.Weight = 1.5
        Add-Text $slide "VERICARGO ONETRUTH" 110 274 500 25 21 $C.White $true 2 | Out-Null
        Add-Text $slide "Detected -> evidenced -> explained -> human-confirmed -> audited" 110 304 500 18 12 $C.Cyan $true 2 | Out-Null
        Add-Text $slide "Challenge: Supply Chain Ontology and Governed Conversational Analytics" 110 330 500 15 9 $C.White $false 2 | Out-Null
        Add-Text $slide "Demo video: [PASTE FINAL 3-5 MINUTE LINK]" 110 348 500 12 8.5 $C.Amber $true 2 | Out-Null

        # Remove any accidental empty title placeholders and save as Open XML presentation.
        $presentation.Save()
    }
    finally {
        $presentation.Close()
    }
}
finally {
    $app.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($app) | Out-Null
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}

Write-Output "Created: $output"

