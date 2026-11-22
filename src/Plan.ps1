param([switch]$Preview, [switch]$Verify)
$ErrorActionPreference = 'Stop'
# Open at every Windows sign-in; the displayed task date is independent.
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
if (-not $Verify) {
    $created = $false
    $instanceMutex = New-Object Threading.Mutex($true, 'Local\LofiCustomPlanner', [ref]$created)
    if (-not $created) { $instanceMutex.Dispose(); return }
}
$statePath = Join-Path $PSScriptRoot 'completed.json'
$settingsPath = Join-Path $PSScriptRoot 'appearance.json'
$notesPath = Join-Path $PSScriptRoot 'notes.json'
$script:notes = @()
if (Test-Path -LiteralPath $notesPath) {
    try { $script:notes = @(Get-Content -LiteralPath $notesPath -Raw -Encoding UTF8 | ConvertFrom-Json | ForEach-Object { $_ } | Where-Object { $_.Text -is [string] -and -not [string]::IsNullOrWhiteSpace($_.Text) }) }
    catch { $script:notes = @() }
}
$script:prefs = @{ Theme='Dark'; Accent='#EC4899'; LightCanvas='#F7F5FA'; DarkCanvas='#1D1B25'; Rounded=$true; Topmost=$true }
$completed = @()
if (Test-Path -LiteralPath $statePath) { try { $completed = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json } catch {} }
if (Test-Path -LiteralPath $settingsPath) {
    try {
        $loaded = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($key in @('Accent','LightCanvas','DarkCanvas')) { if ($loaded.$key -match '^#[0-9A-Fa-f]{6}$') { $script:prefs[$key] = [string]$loaded.$key } }
        if ($loaded.Theme -in @('Light','Dark')) { $script:prefs.Theme = [string]$loaded.Theme }
        foreach ($key in @('Rounded','Topmost')) { if ($loaded.$key -is [bool]) { $script:prefs[$key] = $loaded.$key } }
        foreach ($key in @('WindowLeft','WindowTop')) {
            if ($null -ne $loaded.$key -and $loaded.$key -is [ValueType]) {
                $number = [double]$loaded.$key
                if (-not [double]::IsNaN($number) -and -not [double]::IsInfinity($number)) { $script:prefs[$key] = $number }
            }
        }
    } catch {}
}
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Lofi custom planner" Width="430" Height="540" MinWidth="340" MinHeight="420"
 WindowStyle="None" AllowsTransparency="True" Background="Transparent" ResizeMode="NoResize" FontFamily="Segoe UI" WindowStartupLocation="Manual">
 <Window.Resources>
  <SolidColorBrush x:Key="Accent" Color="#EC4899"/><SolidColorBrush x:Key="Tick" Color="White"/>
  <SolidColorBrush x:Key="Canvas" Color="#1D1B25"/><SolidColorBrush x:Key="Ink" Color="#F6F3FA"/>
  <SolidColorBrush x:Key="Muted" Color="#ABA5BA"/><SolidColorBrush x:Key="Line" Color="#46404F"/>
  <SolidColorBrush x:Key="Soft" Color="#292532"/>
  <Style TargetType="Button">
   <Setter Property="Foreground" Value="{DynamicResource Accent}"/><Setter Property="Background" Value="Transparent"/>
   <Setter Property="BorderBrush" Value="{DynamicResource Line}"/><Setter Property="Padding" Value="9,6"/>
   <Setter Property="Cursor" Value="Hand"/><Setter Property="FontSize" Value="14"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
    <Border x:Name="B" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="8" Padding="{TemplateBinding Padding}">
     <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
    <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="{DynamicResource Soft}"/></Trigger>
     <Trigger Property="IsPressed" Value="True"><Setter TargetName="B" Property="Opacity" Value="0.65"/></Trigger>
    </ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="CheckBox">
   <Setter Property="Foreground" Value="{DynamicResource Ink}"/><Setter Property="FontSize" Value="14"/>
   <Setter Property="Margin" Value="0,7,0,7"/><Setter Property="Cursor" Value="Hand"/>
   <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="CheckBox">
    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="26"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
     <Border x:Name="Box" Width="17" Height="17" CornerRadius="4" BorderThickness="1.5" BorderBrush="{DynamicResource Line}" Background="Transparent" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="0,2,0,0">
      <Path x:Name="Mark" Data="M 1,5 L 4,8 L 10,1" Stroke="{DynamicResource Tick}" StrokeThickness="2" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Width="11" Height="9" Stretch="Uniform" Visibility="Collapsed"/>
     </Border>
     <ContentPresenter x:Name="Words" Grid.Column="1" HorizontalAlignment="Stretch" VerticalAlignment="Top"/>
    </Grid>
    <ControlTemplate.Triggers>
     <Trigger Property="IsChecked" Value="True"><Setter TargetName="Box" Property="Background" Value="{DynamicResource Accent}"/><Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource Accent}"/><Setter TargetName="Mark" Property="Visibility" Value="Visible"/><Setter TargetName="Words" Property="Opacity" Value="0.55"/></Trigger>
     <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource Accent}"/></Trigger>
    </ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
 </Window.Resources>
 <Grid x:Name="Root" Margin="5">
  <Border x:Name="Glass" CornerRadius="22" BorderThickness="1" Padding="3">
   <Border.Effect><DropShadowEffect Color="#EC4899" BlurRadius="10" ShadowDepth="0" Opacity="0.10"/></Border.Effect>
   <Border x:Name="Paper" CornerRadius="18" Background="{DynamicResource Canvas}">
    <Grid Margin="20,15,20,14">
     <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
     <Grid x:Name="DragHeader" Background="Transparent" Margin="0,0,0,13">
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <Grid Background="Transparent" ToolTip="Потягни за заголовок, щоб перемістити вікно">
       <Thumb x:Name="MoveHandle" Cursor="SizeAll"><Thumb.Template><ControlTemplate TargetType="Thumb"><Border Background="Transparent"/></ControlTemplate></Thumb.Template></Thumb>
       <StackPanel VerticalAlignment="Center" IsHitTestVisible="False"><TextBlock Text="МІЙ ПЛАН" Foreground="{DynamicResource Accent}" FontSize="10" FontWeight="Bold"/><TextBlock x:Name="DayLabel" Text="Сьогодні" Foreground="{DynamicResource Ink}" FontSize="22" FontWeight="SemiBold" Margin="0,2,0,0"/></StackPanel>
      </Grid>
      <Button x:Name="ThemeButton" Grid.Column="1" Content="☀" Width="32" Height="31" Padding="0" ToolTip="Світла / темна тема" Margin="3,0"/>
      <Button x:Name="SettingsButton" Grid.Column="2" Content="⚙" Width="32" Height="31" Padding="0" ToolTip="Налаштування" Margin="3,0"/>
      <Button x:Name="MinimizeButton" Grid.Column="3" Content="−" Width="25" Height="31" Padding="0" BorderThickness="0" ToolTip="Згорнути" Margin="3,0"/>
      <Button x:Name="CloseButton" Grid.Column="4" Content="×" Width="25" Height="31" Padding="0" BorderThickness="0" ToolTip="Закрити"/>
     </Grid>
     <Grid Grid.Row="1" Margin="0,0,0,8">
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <TextBlock x:Name="DateLabel" Text="Сьогодні" Foreground="{DynamicResource Muted}" FontSize="12" VerticalAlignment="Center"/>
      <TextBlock Grid.Column="1" Text="6 справ" Foreground="{DynamicResource Muted}" FontSize="12" VerticalAlignment="Center" Margin="0,0,10,0"/>
      <Button x:Name="AddNoteButton" Grid.Column="2" Content="+" Width="29" Height="27" Padding="0" FontSize="20" ToolTip="Створити нотатку"/>
     </Grid>
     <ScrollViewer x:Name="TaskScroll" Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0,0,7,0">
      <StackPanel x:Name="Tasks"><StackPanel.LayoutTransform><ScaleTransform x:Name="TaskScale" ScaleX="1" ScaleY="1"/></StackPanel.LayoutTransform>
       <TextBlock Text="РАНОК" Foreground="{DynamicResource Muted}" FontSize="9" FontWeight="SemiBold" Margin="0,0,0,2"/>
       <CheckBox x:Name="CallMorning" Tag="call-0900"><TextBlock Text="09:00 · Спланувати день" TextWrapping="Wrap"/></CheckBox>
       <Border Background="{DynamicResource Soft}" CornerRadius="10" Padding="10,8" Margin="0,5,0,5"><StackPanel>
        <TextBlock Text="ПРОТЯГОМ ДНЯ" Foreground="{DynamicResource Accent}" FontSize="9" FontWeight="SemiBold" Margin="0,0,0,2"/>
        <CheckBox x:Name="Food" Tag="food"><TextBlock Text="Вийти на прогулянку" TextWrapping="Wrap"/></CheckBox>
        <CheckBox x:Name="ContactCall" Tag="contact-call"><TextBlock Text="Подзвонити колезі" TextWrapping="Wrap"/></CheckBox>
       </StackPanel></Border>
       <CheckBox x:Name="CallAfternoon" Tag="call-1400"><TextBlock Text="14:00 · Зосередитися на головному" TextWrapping="Wrap"/></CheckBox>
       <CheckBox x:Name="GitHubProject" Tag="github-project"><TextBlock Text="Попрацювати над власним проєктом" TextWrapping="Wrap"/></CheckBox>
       <CheckBox x:Name="Friend" Tag="friend-2000"><TextBlock Text="20:00 · Відпочити та підбити підсумки" TextWrapping="Wrap"/></CheckBox>
       <StackPanel x:Name="NotesSection" Visibility="Collapsed" Margin="0,12,0,0">
        <TextBlock Text="НОТАТКИ" Foreground="{DynamicResource Accent}" FontSize="10" FontWeight="SemiBold" Margin="0,0,0,6"/>
        <StackPanel x:Name="NotesList"/>
       </StackPanel>
      </StackPanel>
     </ScrollViewer>
     <Border x:Name="SettingsPanel" Grid.Row="2" Background="{DynamicResource Canvas}" Visibility="Collapsed">
      <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel>
       <TextBlock Text="Оформлення" FontSize="18" FontWeight="SemiBold" Foreground="{DynamicResource Ink}" Margin="0,0,0,14"/>
       <TextBlock Text="Основний колір" Foreground="{DynamicResource Ink}" FontSize="13"/>
       <TextBlock Text="Рамка, галочки, значки та кнопки" Foreground="{DynamicResource Muted}" FontSize="11" Margin="0,3,0,7"/>
       <Button x:Name="AccentButton" HorizontalAlignment="Stretch" Margin="0,0,0,14"><StackPanel Orientation="Horizontal"><Border Width="16" Height="16" CornerRadius="4" Background="{DynamicResource Accent}" Margin="0,0,9,0"/><TextBlock x:Name="AccentValue" Text="#EC4899"/></StackPanel></Button>
       <TextBlock Text="Додатковий колір" Foreground="{DynamicResource Ink}" FontSize="13"/>
       <TextBlock Text="Полотно задач у поточній темі" Foreground="{DynamicResource Muted}" FontSize="11" Margin="0,3,0,7"/>
       <Button x:Name="CanvasButton" HorizontalAlignment="Stretch" Margin="0,0,0,12"><StackPanel Orientation="Horizontal"><Border Width="16" Height="16" CornerRadius="4" Background="{DynamicResource Canvas}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Margin="0,0,9,0"/><TextBlock x:Name="CanvasValue"/></StackPanel></Button>
       <CheckBox x:Name="RoundedToggle"><TextBlock Text="Заокруглені кути" TextWrapping="Wrap"/></CheckBox>
       <TextBlock Text="Вимкни для прямих кутів вікна" Foreground="{DynamicResource Muted}" FontSize="11" Margin="26,0,0,12"/>
       <Button x:Name="SettingsDone" Content="Готово" HorizontalAlignment="Right" Padding="20,7"/>
      </StackPanel></ScrollViewer>
     </Border>
     <Border x:Name="NoteEditorPanel" Grid.Row="2" Background="{DynamicResource Canvas}" Visibility="Collapsed">
      <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
       <TextBlock Text="Нова нотатка" FontSize="18" FontWeight="SemiBold" Foreground="{DynamicResource Ink}" Margin="0,0,0,12"/>
       <Border Grid.Row="1" BorderBrush="{DynamicResource Accent}" BorderThickness="1" CornerRadius="8" Padding="10" Background="{DynamicResource Soft}">
        <TextBox x:Name="NoteInput" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="Transparent" Foreground="{DynamicResource Ink}" CaretBrush="{DynamicResource Accent}" BorderThickness="0" FontFamily="Segoe UI" FontSize="14" MaxLength="10000" ToolTip="Напиши текст нотатки"/>
       </Border>
       <TextBlock x:Name="NoteError" Grid.Row="2" Foreground="{DynamicResource Accent}" FontSize="11" TextWrapping="Wrap" Margin="0,7,0,7"/>
       <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="NoteCancel" Content="Скасувати" Margin="0,0,8,0"/>
        <Button x:Name="NoteSave" Content="Додати"/>
       </StackPanel>
      </Grid>
     </Border>
     <StackPanel Grid.Row="3" Margin="0,11,0,0">
      <Grid><TextBlock x:Name="Progress" Foreground="{DynamicResource Muted}" FontSize="11"/><TextBlock Text="↘ потягни за край" Foreground="{DynamicResource Muted}" FontSize="10" HorizontalAlignment="Right"/></Grid>
      <ProgressBar x:Name="ProgressBar" Maximum="6" Height="3" Foreground="{DynamicResource Accent}" Background="{DynamicResource Soft}" BorderThickness="0" Margin="0,7,0,6"/>
      <CheckBox x:Name="KeepOnTop" FontSize="11" Margin="0,3,0,3"><TextBlock Text="Поверх інших вікон"/></CheckBox>
      <TextBlock x:Name="SaveStatus" Text="Зміни зберігаються автоматично" Foreground="{DynamicResource Muted}" FontSize="9" TextWrapping="Wrap"/>
     </StackPanel>
    </Grid>
   </Border>
  </Border>
  <Thumb x:Name="ResizeLeft" Width="7" HorizontalAlignment="Left" Cursor="SizeWE" Tag="Left"/>
  <Thumb x:Name="ResizeRight" Width="7" HorizontalAlignment="Right" Cursor="SizeWE" Tag="Right"/>
  <Thumb x:Name="ResizeTop" Height="7" VerticalAlignment="Top" Cursor="SizeNS" Tag="Top"/>
  <Thumb x:Name="ResizeBottom" Height="7" VerticalAlignment="Bottom" Cursor="SizeNS" Tag="Bottom"/>
  <Thumb x:Name="ResizeCorner" Width="17" Height="17" HorizontalAlignment="Right" VerticalAlignment="Bottom" Cursor="SizeNWSE" Tag="Corner"/>
 </Grid>
</Window>
'@
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
foreach ($name in @('Glass','Paper','ThemeButton','SettingsButton','MinimizeButton','CloseButton','DragHeader','MoveHandle','TaskScale','Tasks','TaskScroll','SettingsPanel','AccentButton','CanvasButton','AccentValue','CanvasValue','RoundedToggle','SettingsDone','Progress','ProgressBar','KeepOnTop','SaveStatus','AddNoteButton','NotesSection','NotesList','NoteEditorPanel','NoteInput','NoteError','NoteCancel','NoteSave')) {
    Set-Variable -Name $name -Value $window.FindName($name)
}
$culture=[cultureinfo]::GetCultureInfo('uk-UA')
$window.FindName('DayLabel').Text=$culture.TextInfo.ToTitleCase((Get-Date).ToString('dddd',$culture))
$window.FindName('DateLabel').Text=(Get-Date).ToString('d MMMM yyyy',$culture)
$taskBoxes = @('CallMorning','Food','ContactCall','CallAfternoon','GitHubProject','Friend') | ForEach-Object { $window.FindName($_) }
function Brush([string]$hex) { return [Windows.Media.BrushConverter]::new().ConvertFromString($hex) }
function Update-Progress {
    $done = @($taskBoxes | Where-Object { $_.IsChecked -eq $true }).Count
    $Progress.Text = "Виконано $done із 6"
    $ProgressBar.Value = $done
}
function Save-Preferences {
    try { [IO.File]::WriteAllText($settingsPath, ($script:prefs | ConvertTo-Json), [Text.UTF8Encoding]::new($false)); $SaveStatus.Text = 'Зміни зберігаються автоматично' }
    catch { $SaveStatus.Text = 'Не вдалося зберегти оформлення'; if ($Verify) { throw } }
}
function Render-Notes {
    $NotesList.Children.Clear()
    foreach ($note in $script:notes) {
        $card = [Windows.Controls.Border]::new()
        $card.CornerRadius = [Windows.CornerRadius]::new(8)
        $card.Padding = [Windows.Thickness]::new(10)
        $card.Margin = [Windows.Thickness]::new(0,0,0,7)
        $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty,'Soft')
        $text = [Windows.Controls.TextBlock]::new()
        $text.Text = [string]$note.Text
        $text.TextWrapping = 'Wrap'; $text.FontSize = 14
        $text.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'Ink')
        $card.Child = $text
        [void]$NotesList.Children.Add($card)
    }
    $NotesSection.Visibility = if ($script:notes.Count -gt 0) { 'Visible' } else { 'Collapsed' }
}
function Save-NewNote {
    $value = $NoteInput.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { $NoteError.Text='Спершу напиши текст нотатки.'; return }
    $newNote = [pscustomobject]@{ Id=[guid]::NewGuid().ToString('N'); Text=$value; Created=(Get-Date).ToString('o') }
    $updated = @($script:notes) + @($newNote)
    try {
        [IO.File]::WriteAllText($notesPath,(ConvertTo-Json -InputObject $updated -Depth 4),[Text.UTF8Encoding]::new($false))
    } catch { $NoteError.Text='Не вдалося зберегти. Текст залишився у полі — спробуй ще раз.'; return }
    $script:notes=$updated
    Render-Notes
    $NoteInput.Clear(); $NoteError.Text=''; $NoteEditorPanel.Visibility='Collapsed'
    $SaveStatus.Text='Нотатку збережено'
    $window.UpdateLayout(); $TaskScroll.ScrollToEnd()
}
function Apply-Appearance {
    $canvasHex = if ($script:prefs.Theme -eq 'Dark') { $script:prefs.DarkCanvas } else { $script:prefs.LightCanvas }
    $canvasColor = [Windows.Media.ColorConverter]::ConvertFromString($canvasHex)
    $bright = (0.2126*$canvasColor.R + 0.7152*$canvasColor.G + 0.0722*$canvasColor.B) -gt 140
    $window.Resources['Canvas'] = Brush $canvasHex
    $window.Resources['Accent'] = Brush $script:prefs.Accent
    $accentColor = [Windows.Media.ColorConverter]::ConvertFromString($script:prefs.Accent)
    $accentBright = (0.2126*$accentColor.R + 0.7152*$accentColor.G + 0.0722*$accentColor.B) -gt 155
    $window.Resources['Tick'] = Brush $(if ($accentBright) { '#19151E' } else { '#FFFFFF' })
    if ($bright) {
        $window.Resources['Ink'] = Brush '#24202D'; $window.Resources['Muted'] = Brush '#746A80'; $window.Resources['Line'] = Brush '#C5BBCE'; $window.Resources['Soft'] = Brush '#EAE5F0'
    } else {
        $window.Resources['Ink'] = Brush '#F5F0FA'; $window.Resources['Muted'] = Brush '#B0A5BC'; $window.Resources['Line'] = Brush '#64576F'; $window.Resources['Soft'] = Brush '#302936'
    }
    $gradient = [Windows.Media.LinearGradientBrush]::new()
    $gradient.StartPoint = [Windows.Point]::new(0,0); $gradient.EndPoint = [Windows.Point]::new(1,1)
    $gradient.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString('#C0FFFFFF'),0))
    $gradient.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString('#A0' + $script:prefs.Accent.Substring(1)),0.4))
    $gradient.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString('#25FFFFFF'),0.7))
    $gradient.GradientStops.Add([Windows.Media.GradientStop]::new($accentColor,1))
    $Glass.BorderBrush = $gradient
    $Glass.Background = Brush ('#18' + $script:prefs.Accent.Substring(1))
    $Glass.Effect.Color = $accentColor
    $Glass.CornerRadius = [Windows.CornerRadius]::new($(if ($script:prefs.Rounded) { 22 } else { 0 }))
    $Paper.CornerRadius = [Windows.CornerRadius]::new($(if ($script:prefs.Rounded) { 18 } else { 0 }))
    $RoundedToggle.IsChecked = $script:prefs.Rounded
    $KeepOnTop.IsChecked = $script:prefs.Topmost; $window.Topmost = $script:prefs.Topmost
    $ThemeButton.Content = if ($script:prefs.Theme -eq 'Dark') { '☀' } else { '☾' }
    $AccentValue.Text = $script:prefs.Accent; $CanvasValue.Text = $canvasHex
}
function Choose-Color([bool]$isAccent) {
    $key = if ($isAccent) { 'Accent' } elseif ($script:prefs.Theme -eq 'Dark') { 'DarkCanvas' } else { 'LightCanvas' }
    $dialog = [Windows.Forms.ColorDialog]::new()
    $dialog.FullOpen = $true; $dialog.Color = [Drawing.ColorTranslator]::FromHtml($script:prefs[$key])
    $wasTopmost = $window.Topmost; $window.Topmost = $false
    try {
        if ($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
            $script:prefs[$key] = '#{0:X2}{1:X2}{2:X2}' -f $dialog.Color.R,$dialog.Color.G,$dialog.Color.B
            Apply-Appearance; Save-Preferences
        }
    } finally { $dialog.Dispose(); $window.Topmost = $wasTopmost; $window.Activate() | Out-Null }
}
foreach ($box in $taskBoxes) {
    $box.IsChecked = $completed -contains [string]$box.Tag
    $box.Add_Click({
        $ids = @($taskBoxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { [string]$_.Tag })
        try { [IO.File]::WriteAllText($statePath, (ConvertTo-Json -InputObject $ids), [Text.UTF8Encoding]::new($false)); $SaveStatus.Text = 'Галочки збережено' }
        catch { $SaveStatus.Text = 'Не вдалося зберегти галочки' }
        Update-Progress
    })
}
$ThemeButton.Add_Click({ $script:prefs.Theme = if ($script:prefs.Theme -eq 'Dark') { 'Light' } else { 'Dark' }; Apply-Appearance; Save-Preferences })
$SettingsButton.Add_Click({ $NoteEditorPanel.Visibility='Collapsed'; $SettingsPanel.Visibility = if ($SettingsPanel.Visibility -eq 'Visible') { 'Collapsed' } else { 'Visible' } })
$AddNoteButton.Add_Click({ $SettingsPanel.Visibility='Collapsed'; $NoteEditorPanel.Visibility='Visible'; $NoteError.Text=''; [void]$NoteInput.Focus() })
$NoteSave.Add_Click({ Save-NewNote })
$NoteCancel.Add_Click({ $NoteInput.Clear(); $NoteError.Text=''; $NoteEditorPanel.Visibility='Collapsed' })
$SettingsDone.Add_Click({ $SettingsPanel.Visibility = 'Collapsed' })
$AccentButton.Add_Click({ Choose-Color $true }); $CanvasButton.Add_Click({ Choose-Color $false })
$RoundedToggle.Add_Click({ $script:prefs.Rounded = $RoundedToggle.IsChecked -eq $true; Apply-Appearance; Save-Preferences })
$KeepOnTop.Add_Click({ $script:prefs.Topmost = $KeepOnTop.IsChecked -eq $true; Apply-Appearance; Save-Preferences })
$CloseButton.Add_Click({ $window.Close() }); $MinimizeButton.Add_Click({ $window.WindowState = 'Minimized' })
$MoveHandle.Add_DragDelta({ param($sender,$eventArgs)
    $window.Left += $eventArgs.HorizontalChange
    $window.Top += $eventArgs.VerticalChange
})
$MoveHandle.Add_DragCompleted({
    $script:prefs.WindowLeft=$window.Left; $script:prefs.WindowTop=$window.Top
    Save-Preferences
})
$window.Add_SizeChanged({
    $factor = [Math]::Max(0.78,[Math]::Min(1.8,[Math]::Sqrt(($window.ActualWidth/430.0)*($window.ActualHeight/540.0))))
    $TaskScale.ScaleX = $factor; $TaskScale.ScaleY = $factor
})
foreach ($gripName in @('ResizeLeft','ResizeRight','ResizeTop','ResizeBottom','ResizeCorner')) {
    $grip = $window.FindName($gripName)
    $template = [Windows.Controls.ControlTemplate]::new([Windows.Controls.Primitives.Thumb])
    $factory = [Windows.FrameworkElementFactory]::new([Windows.Controls.Border])
    $factory.SetValue([Windows.Controls.Border]::BackgroundProperty,[Windows.Media.Brushes]::Transparent)
    $template.VisualTree = $factory; $grip.Template = $template
    $grip.Add_DragDelta({
        $direction = [string]$this.Tag
        if ($direction -in @('Right','Corner')) { $window.Width = [Math]::Max($window.MinWidth,$window.Width + $_.HorizontalChange) }
        if ($direction -in @('Bottom','Corner')) { $window.Height = [Math]::Max($window.MinHeight,$window.Height + $_.VerticalChange) }
        if ($direction -eq 'Left') { $old = $window.Width; $window.Width = [Math]::Max($window.MinWidth,$old - $_.HorizontalChange); $window.Left += $old-$window.Width }
        if ($direction -eq 'Top') { $old = $window.Height; $window.Height = [Math]::Max($window.MinHeight,$old - $_.VerticalChange); $window.Top += $old-$window.Height }
    })
}
Apply-Appearance; Update-Progress; Render-Notes
$area = [Windows.SystemParameters]::WorkArea
$window.Left = [Math]::Max($area.Left,$area.Right-$window.Width-20); $window.Top=$area.Top+24
if ($script:prefs.ContainsKey('WindowLeft') -and $script:prefs.ContainsKey('WindowTop')) {
    $window.Left=[Math]::Max([Windows.SystemParameters]::VirtualScreenLeft,[Math]::Min($script:prefs.WindowLeft,[Windows.SystemParameters]::VirtualScreenLeft+[Windows.SystemParameters]::VirtualScreenWidth-$window.Width))
    $window.Top=[Math]::Max([Windows.SystemParameters]::VirtualScreenTop,[Math]::Min($script:prefs.WindowTop,[Windows.SystemParameters]::VirtualScreenTop+[Windows.SystemParameters]::VirtualScreenHeight-$window.Height))
}
if ($Verify) {
    $window.Show(); $window.UpdateLayout()
    $NoteInput.Text='   '
    Save-NewNote
    if ($script:notes.Count -ne 0 -or [string]::IsNullOrEmpty($NoteError.Text)) { throw 'Blank note validation failed' }
    $NoteInput.Text="Українська нотатка <tag> & текст`nДругий рядок"
    Save-NewNote
    $savedNotes=Get-Content -LiteralPath $notesPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (@($savedNotes).Count -ne 1 -or $savedNotes[0].Text -ne "Українська нотатка <tag> & текст`nДругий рядок" -or $NotesList.Children.Count -ne 1) { throw 'Unicode multiline note save/render failed' }
    $NoteInput.Text='Скасована нотатка'
    $NoteCancel.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    if ($script:notes.Count -ne 1 -or $NoteInput.Text -ne '') { throw 'Cancel note failed' }
    $oldLeft=$window.Left; $oldTop=$window.Top
    $moveArgs=[Windows.Controls.Primitives.DragDeltaEventArgs]::new(-45,25)
    $moveArgs.RoutedEvent=[Windows.Controls.Primitives.Thumb]::DragDeltaEvent
    $MoveHandle.RaiseEvent($moveArgs)
    if ($window.Left -ne $oldLeft-45 -or $window.Top -ne $oldTop+25) { throw 'Window drag failed' }
    $endMove=[Windows.Controls.Primitives.DragCompletedEventArgs]::new(-45,25,$false)
    $endMove.RoutedEvent=[Windows.Controls.Primitives.Thumb]::DragCompletedEvent
    $MoveHandle.RaiseEvent($endMove)
    $savedPrefs=Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($savedPrefs.WindowLeft -ne $window.Left -or $savedPrefs.WindowTop -ne $window.Top) { throw 'Window position persistence failed' }
    foreach ($size in @(@(430,540),@(340,420),@(860,1080))) {
        $window.Width=$size[0]; $window.Height=$size[1]; $window.UpdateLayout()
        if ($Tasks.ActualWidth -le 0 -or $taskBoxes.Count -ne 6) { throw 'Task layout failed' }
    }
    $window.Width=430; $window.Height=540; $window.UpdateLayout()
    $ThemeButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    if ($script:prefs.Theme -ne 'Light') { throw 'Theme toggle failed' }
    $ThemeButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    $RoundedToggle.IsChecked=$false; $RoundedToggle.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    if ($Glass.CornerRadius.TopLeft -ne 0) { throw 'Square mode failed' }
    $RoundedToggle.IsChecked=$true; $RoundedToggle.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    $taskBoxes[1].IsChecked=$true; $taskBoxes[1].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    if ((Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json) -notcontains 'food') { throw 'Checkbox save failed' }
    $taskBoxes[1].IsChecked=$false; $taskBoxes[1].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(430,540,96,96,[Windows.Media.PixelFormats]::Pbgra32)
    $window.UpdateLayout(); $bitmap.Render($window)
    $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create((Join-Path $PSScriptRoot 'preview.png')); try { $encoder.Save($stream) } finally { $stream.Dispose() }
    $window.Close()
    'PASS: 6 tasks, 3 sizes, themes/corners, checkbox saving, blank/multiline Unicode notes, cancel, window drag and saved position'
    return
}
$window.Add_ContentRendered({ $window.Activate() | Out-Null })
try { [void]$window.ShowDialog() } finally { $instanceMutex.ReleaseMutex(); $instanceMutex.Dispose() }
