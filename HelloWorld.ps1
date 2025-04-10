Add-Type -AssemblyName System.Windows.Forms

$form = New-Object System.Windows.Forms.Form
$form.Text = "Mon interface"
$form.Width = 300
$form.Height = 200

$label = New-Object System.Windows.Forms.Label
$label.Text = "Hello World"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(100, 80)

$form.Controls.Add($label)

$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
