{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Handler.EmployeeCreate where

import Import
import Rentier.EmployeeInvitationStatus
import Rentier.Rational ()
import Rentier.SimpleForm
import Rentier.Utils
import Yesod.Form.Bootstrap3

getEmployeeCreateR :: MerchantId -> Handler Html
getEmployeeCreateR merchantId = do
  (_, user) <- requireAuthPair
  (formWidget, formEnctype) <-
    generateFormPost $
      renderBootstrap3
        BootstrapBasicForm
        (aForm merchantId)
  renderSimpleForm formWidget formEnctype (formSettings user merchantId)

postEmployeeCreateR :: MerchantId -> Handler Html
postEmployeeCreateR merchantId = do
  (_, user) <- requireAuthPair
  ((formResult, formWidget), formEnctype) <-
    runFormPost $
      renderBootstrap3
        BootstrapBasicForm
        (aForm merchantId)
  case formResult of
    FormSuccess formSuccess -> do
      _ <-
        runDB $
          insert400
            formSuccess
              { employeeMerchantId = merchantId,
                employeeInvitationStatus = Pending
              }
      setMessageI MsgEmployeeCreated
      redirect $ EmployeeListR merchantId
    _ ->
      renderSimpleForm formWidget formEnctype (formSettings user merchantId)

aForm :: MerchantId -> AForm Handler Employee
aForm merchantId =
  Employee
    <$> areq hiddenField (bfs MsgNothing) (Just merchantId)
    <*> ( UserIdent'
            <$> areq
              employeeIdentField
              (bfsAutoFocus MsgEmployeeIdent)
              Nothing
        )
    <*> areq hiddenField (bfs MsgNothing) (Just Pending)
    <*> areq hiddenField (bfs MsgNothing) (Just True)
    <*> areq hiddenField (bfs MsgNothing) (Just True)
  where
    employeeIdentField :: Field Handler Text
    employeeIdentField =
      checkM
        (verifyEmployeeIdent merchantId)
        textField

verifyEmployeeIdent ::
  MerchantId ->
  Text ->
  Handler (Either AppMessage Text)
verifyEmployeeIdent merchantId ident = do
  mm <- runDB $ getBy $ UniqueEmployee merchantId $ UserIdent' ident
  return $ case mm of
    Just _ -> Left MsgAlreadyExists
    Nothing -> Right ident

formSettings :: User -> MerchantId -> SimpleFormSettings
formSettings user merchantId =
  SimpleFormSettings
    { formRoute = EmployeeCreateR merchantId,
      formMsgSubmit = MsgEmployeeCreate,
      formPageTitle = MsgEmployeeCreateRTitle user,
      formLayout = defaultLayout
    }
